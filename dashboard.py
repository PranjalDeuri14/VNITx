import base64
import json
import os
import shutil
import subprocess
import tempfile
from datetime import datetime
from io import BytesIO
from typing import Any, Dict, Optional, Tuple

import httpx
import streamlit as st

try:
    from pydub import AudioSegment

    _PYDUB_AVAILABLE = True
except Exception:
    AudioSegment = None
    _PYDUB_AVAILABLE = False

from screen_capture_component import screen_capture


st.set_page_config(page_title="VNITx Security Dashboard", layout="wide")


DEFAULT_AUDIO_BASE = "https://arshan123-vnitx-audio.hf.space"
DEFAULT_IMAGE_BASE = "https://arshan123-vnitx-image.hf.space"
DEFAULT_VIDEO_BASE = "https://arshan123-vnitx-video.hf.space"


def _safe_json(resp: httpx.Response) -> Dict[str, Any]:
    try:
        return resp.json()
    except json.JSONDecodeError:
        return {"raw_text": resp.text}


def _bool_str(value: bool) -> str:
    return "true" if value else "false"


def _post_image(
    base_url: str,
    image_bytes: bytes,
    filename: str,
    content_type: str,
    audio_transcript: str,
    run_caption: bool,
    deep: bool,
) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
    try:
        with httpx.Client(timeout=300) as client:
            resp = client.post(
                f"{base_url.rstrip('/')}/analyze",
                files={"image": (filename, image_bytes, content_type or "image/jpeg")},
                data={
                    "audio_transcript": audio_transcript,
                    "run_caption": _bool_str(run_caption),
                    "deep": _bool_str(deep),
                },
            )
        resp.raise_for_status()
        return _safe_json(resp), None
    except httpx.HTTPError as exc:
        return None, str(exc)


def _post_video(
    base_url: str,
    video_bytes: bytes,
    filename: str,
    content_type: str,
    audio_transcript: str,
    target_fps: float,
    max_frames: Optional[int],
    run_injection: bool,
    run_cross_modal: bool,
    run_caption: bool,
    run_vision_deepfake: bool,
    run_avsync: bool,
    log_frames: bool,
    crop: Optional[Dict[str, Any]] = None,
) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
    try:
        with httpx.Client(timeout=600) as client:
            resp = client.post(
                f"{base_url.rstrip('/')}/analyze_video",
                files={"video": (filename, video_bytes, content_type or "video/mp4")},
                data={
                    "audio_transcript": audio_transcript,
                    "target_fps": str(target_fps),
                    "max_frames": "" if max_frames is None else str(max_frames),
                    "run_injection": _bool_str(run_injection),
                    "run_cross_modal": _bool_str(run_cross_modal),
                    "run_caption": _bool_str(run_caption),
                    "run_vision_deepfake": _bool_str(run_vision_deepfake),
                    "run_avsync": _bool_str(run_avsync),
                    "log_frames": _bool_str(log_frames),
                    "crop_x": "" if not crop else str(int(crop.get("x", 0))),
                    "crop_y": "" if not crop else str(int(crop.get("y", 0))),
                    "crop_w": "" if not crop else str(int(crop.get("w", 0))),
                    "crop_h": "" if not crop else str(int(crop.get("h", 0))),
                },
            )
        resp.raise_for_status()
        return _safe_json(resp), None
    except httpx.HTTPError as exc:
        return None, str(exc)


def _post_audio(
    base_url: str,
    api_key: str,
    audio_bytes: bytes,
    language: str,
    audio_format: str,
) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
    try:
        audio_b64 = base64.b64encode(audio_bytes).decode("ascii")
        with httpx.Client(timeout=300) as client:
            resp = client.post(
                f"{base_url.rstrip('/')}/api/voice-detection",
                headers={"x-api-key": api_key, "Content-Type": "application/json"},
                json={
                    "language": language,
                    "audioFormat": audio_format,
                    "audioBase64": audio_b64,
                },
            )
        resp.raise_for_status()
        return _safe_json(resp), None
    except httpx.HTTPStatusError as exc:
        response_text = exc.response.text if exc.response is not None else ""
        return None, f"{exc} | response: {response_text[:500]}"
    except httpx.HTTPError as exc:
        return None, str(exc)


def _convert_to_mp3(
    audio_bytes: bytes,
    source_format: str,
    bitrate: str = "64k",
    sample_rate: int = 16000,
    channels: int = 1,
) -> Tuple[Optional[bytes], Optional[str]]:
    if source_format.lower() == "mp3":
        return audio_bytes, None
    if not _PYDUB_AVAILABLE:
        return (
            None,
            "Microphone recording is WAV. Install `pydub` and `ffmpeg` to convert to MP3.",
        )
    try:
        audio = AudioSegment.from_file(BytesIO(audio_bytes), format=source_format)
        audio = audio.set_frame_rate(sample_rate).set_channels(channels)
        buffer = BytesIO()
        audio.export(buffer, format="mp3", bitrate=bitrate)
        return buffer.getvalue(), None
    except Exception as exc:
        return None, f"MP3 conversion failed: {exc}"


def _extract_audio_mp3_from_video(video_bytes: bytes, filename: str) -> Tuple[Optional[bytes], Optional[str]]:
    if not _PYDUB_AVAILABLE:
        return None, "Install `pydub` and `ffmpeg` to extract audio from video."
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "mp4"
    try:
        audio = AudioSegment.from_file(BytesIO(video_bytes), format=ext)
        audio = audio.set_frame_rate(44100).set_channels(1)
        buffer = BytesIO()
        audio.export(buffer, format="mp3", bitrate="192k")
        return buffer.getvalue(), None
    except Exception as exc:
        return None, f"Audio extraction failed: {exc}"


def _guess_ext(filename: str) -> str:
    if "." not in filename:
        return ""
    return filename.rsplit(".", 1)[-1].lower().strip()


def _convert_video_to_mp4(
    video_bytes: bytes,
    filename: str,
    crop: Optional[Dict[str, Any]] = None,
) -> Tuple[Optional[bytes], Optional[str]]:
    """
    Convert arbitrary video bytes to MP4 (H.264 + optional AAC) via ffmpeg.
    If `crop` is provided, crop is applied during conversion.
    """
    if shutil.which("ffmpeg") is None:
        return None, "ffmpeg not found. Install it (e.g. `brew install ffmpeg`) and retry."

    ext = _guess_ext(filename) or "webm"
    src = tempfile.NamedTemporaryFile(delete=False, suffix=f".{ext}")
    dst = tempfile.NamedTemporaryFile(delete=False, suffix=".mp4")
    src_path = src.name
    dst_path = dst.name
    try:
        src.write(video_bytes)
        src.flush()
        src.close()
        dst.close()

        # Keep uploads small and decoder-friendly: downscale to max width 640, lower fps.
        vf = "scale='if(gt(iw,640),640,iw)':-2"
        if crop:
            try:
                x = max(0, int(crop.get("x", 0)))
                y = max(0, int(crop.get("y", 0)))
                w = max(2, int(crop.get("w", 0)))
                h = max(2, int(crop.get("h", 0)))
                vf = f"crop={w}:{h}:{x}:{y}," + vf
            except Exception:
                pass

        cmd = [
            "ffmpeg",
            "-y",
            "-i",
            src_path,
            "-vf",
            vf,
            "-r",
            "15",
            "-map",
            "0:v:0",
            "-map",
            "0:a:0?",
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "28",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            "-movflags",
            "+faststart",
            dst_path,
        ]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        with open(dst_path, "rb") as handle:
            return handle.read(), None
    except subprocess.CalledProcessError:
        return None, "ffmpeg conversion failed. Try a shorter capture (<=10s) and re-run."
    finally:
        try:
            os.unlink(src_path)
        except Exception:
            pass
        try:
            os.unlink(dst_path)
        except Exception:
            pass


def _health_check(base_url: str, path: str) -> Tuple[bool, str]:
    try:
        with httpx.Client(timeout=15) as client:
            resp = client.get(f"{base_url.rstrip('/')}{path}")
        resp.raise_for_status()
        return True, resp.text[:200]
    except httpx.HTTPError as exc:
        return False, str(exc)


st.title("VNITx Multimodal Security Dashboard")
st.caption("HackIITK 2026 demo console for Audio + Image + Video defenses.")

with st.sidebar:
    st.header("API Endpoints")
    audio_base = st.text_input("Audio Base URL", value=os.environ.get("AUDIO_BASE", DEFAULT_AUDIO_BASE))
    image_base = st.text_input("Image Base URL", value=os.environ.get("IMAGE_BASE", DEFAULT_IMAGE_BASE))
    video_base = st.text_input("Video Base URL", value=os.environ.get("VIDEO_BASE", DEFAULT_VIDEO_BASE))
    st.divider()
    audio_api_key = st.text_input(
        "Audio API Key",
        type="password",
        value=os.environ.get("AUDIO_API_KEY", "sk_test_123456789"),
    )
    st.caption("Audio endpoint requires `x-api-key` header.")

tab_overview, tab_audio, tab_image, tab_video, tab_debug = st.tabs(
    ["Overview", "Audio", "Image", "Video", "Debug"]
)

with tab_overview:
    st.subheader("System Snapshot")
    col_a, col_b, col_c = st.columns(3)
    with col_a:
        st.metric("Audio Space", "vnitx-audio")
        ok, msg = _health_check(audio_base, "/health")
        st.write("Health:", "OK" if ok else "Down")
    with col_b:
        st.metric("Image Space", "VNITx-Image")
        ok, msg = _health_check(image_base, "/")
        st.write("Health:", "OK" if ok else "Down")
    with col_c:
        st.metric("Video Space", "vnitx-video")
        ok, msg = _health_check(video_base, "/")
        st.write("Health:", "OK" if ok else "Down")

    st.markdown(
        """
This dashboard connects directly to our deployed Hugging Face Spaces:
- **Audio**: deepfake voice detection + streaming endpoint  
- **Image**: prompt injection + cross-modal consistency  
- **Video**: prompt injection + deepfake frames + AV sync  

The system unifies multimodal defenses for media integrity: audio spoofing, image prompt injection,
and video deepfake risk scoring. Each Space exposes a single API endpoint:
- Audio: `POST /api/voice-detection`
- Image: `POST /analyze`
- Video: `POST /analyze_video`
"""
    )

with tab_audio:
    st.subheader("Audio Deepfake Detection")
    st.markdown("Upload MP3 or record live audio for AI vs Human classification.")
    with st.expander("Why false positives can happen"):
        st.markdown(
            """
- Very clean recordings (noise suppression / auto‑gain) can look “synthetic”
- Short clips or steady singing can reduce natural variability
- Browser mic pipelines can flatten energy and pitch dynamics

If a real voice is flagged, try a 20–30s natural speech clip or a phone‑recorded MP3.
"""
        )
    audio_source = st.radio("Audio source", ["Upload MP3", "Record (WAV)"], horizontal=True)
    audio_file = None
    recorded_audio = None
    if audio_source == "Upload MP3":
        audio_file = st.file_uploader("Upload audio (mp3)", type=["mp3"])
    else:
        recorded_audio = st.audio_input("Record audio", key="audio_mic")
    language = st.selectbox("Language", ["English", "Tamil", "Hindi", "Malayalam", "Telugu"], index=0)
    audio_format = st.text_input("Audio Format", value="mp3", disabled=audio_source != "Upload MP3")
    compress_audio = st.checkbox("Compress for API (smaller MP3)", value=False)

    audio_bytes = None
    source_format = "mp3"
    if audio_file:
        st.audio(audio_file)
        audio_bytes = audio_file.getvalue()
        source_format = audio_format
    elif recorded_audio:
        st.audio(recorded_audio)
        audio_bytes = recorded_audio.getvalue()
        source_format = "wav"

    if audio_bytes:
        st.caption(f"Audio size: {len(audio_bytes) / (1024 * 1024):.2f} MB")
        if st.button("Analyze Audio"):
            if not audio_api_key:
                st.error("Audio API key required.")
            else:
                if source_format.lower() != "mp3":
                    audio_bytes, conv_err = _convert_to_mp3(
                        audio_bytes,
                        source_format,
                        bitrate="96k" if compress_audio else "192k",
                        sample_rate=22050 if compress_audio else 44100,
                        channels=1,
                    )
                    if conv_err:
                        st.error(conv_err)
                        audio_bytes = None
                if audio_bytes and len(audio_bytes) > 12 * 1024 * 1024:
                    st.warning("Audio is large; consider a shorter clip (<=30s) for stability.")
                if audio_bytes:
                    with st.spinner("Calling audio API..."):
                        payload, err = _post_audio(
                            audio_base,
                            audio_api_key,
                            audio_bytes,
                            language,
                            "mp3",
                        )
                    if err:
                        st.error(err)
                    else:
                        st.success("Audio analysis complete")
                        st.json(payload)

    with st.expander("Request Example (cURL)"):
        st.code(
            f"""curl -X POST "{audio_base}/api/voice-detection" \\
  -H "Content-Type: application/json" \\
  -H "x-api-key: <YOUR_KEY>" \\
  -d '{{"language":"English","audioFormat":"mp3","audioBase64":"<BASE64>"}}'""",
            language="bash",
        )

with tab_image:
    st.subheader("Image Prompt Injection + Cross-Modal")
    st.markdown("Upload an image and optionally provide audio transcript text.")
    image_file = st.file_uploader("Upload image", type=["jpg", "jpeg", "png"])
    audio_transcript = st.text_area(
        "Audio transcript (optional)", height=100, key="image_audio_transcript"
    )
    run_caption = st.checkbox("Run BLIP caption alignment", value=True)
    deep_mode = st.checkbox("Use deep model (DeBERTa)", value=True)

    if image_file:
        st.image(image_file, caption=image_file.name, use_column_width=True)
        if st.button("Analyze Image"):
            with st.spinner("Calling image API..."):
                payload, err = _post_image(
                    image_base,
                    image_file.getvalue(),
                    image_file.name,
                    image_file.type or "image/jpeg",
                    audio_transcript,
                    run_caption,
                    deep_mode,
                )
            if err:
                st.error(err)
            else:
                st.success("Image analysis complete")
                st.json(payload)

    with st.expander("Request Example (cURL)"):
        st.code(
            f"""curl -X POST "{image_base}/analyze" \\
  -F "image=@sample.jpg" \\
  -F "audio_transcript=..." \\
  -F "run_caption=true" \\
  -F "deep=true" """,
            language="bash",
        )

with tab_video:
    st.subheader("Video Deepfake + Prompt Injection")
    st.markdown("Upload a video. The timeline will highlight risky frames.")
    video_source = st.radio(
        "Video source",
        ["Upload file", "Capture tab/screen (select region)"],
        horizontal=True,
    )
    video_file = None
    captured_video = None
    if video_source == "Upload file":
        video_file = st.file_uploader("Upload video", type=["mp4", "mov", "avi", "mkv", "webm"])
    else:
        st.caption("Tip: keep captures short (default 10s) to avoid large uploads.")
        captured_video = screen_capture(
            key="screen_capture_video",
            max_seconds=10,
            fps=20,
            video_bits_per_second=1_500_000,
        )
    video_transcript = st.text_area(
        "Audio transcript (optional)", height=100, key="video_audio_transcript"
    )
    extract_audio = st.checkbox("Also analyze extracted audio with Audio API", value=True)
    extracted_audio_language = st.selectbox(
        "Extracted audio language",
        ["English", "Tamil", "Hindi", "Malayalam", "Telugu"],
        index=0,
        disabled=not extract_audio,
    )
    fast_default = video_source != "Upload file"
    fast_mode = st.checkbox(
        "Fast mode (recommended for capture / HF Spaces)",
        value=fast_default,
        help="Reduces FPS + caps frames + disables heaviest checks to avoid long waits.",
    )
    if fast_mode:
        st.caption("Fast mode suggestions: 1–2 FPS, max 20–40 frames. Enable more checks only if needed.")

    col1, col2, col3 = st.columns(3)
    with col1:
        target_fps = st.number_input(
            "Target FPS",
            min_value=1.0,
            max_value=30.0,
            value=2.0 if fast_mode else 5.0,
            key="video_target_fps_root",
        )
    with col2:
        max_frames = st.number_input(
            "Max Frames (0 = no limit)",
            min_value=0,
            max_value=5000,
            value=30 if fast_mode else 0,
            key="video_max_frames_root",
        )
    with col3:
        log_frames = st.checkbox("Log per-frame JSONL", value=not fast_mode)

    st.caption("Toggle detectors")
    run_injection = st.checkbox("Run prompt injection", value=True)
    run_cross_modal = st.checkbox("Run cross-modal checks", value=not fast_mode)
    run_caption = st.checkbox("Run caption alignment", value=False if fast_mode else True)
    run_vision_deepfake = st.checkbox("Run vision deepfake", value=False if fast_mode else True)
    run_avsync = st.checkbox("Run AV sync", value=False if fast_mode else True)

    video_bytes: Optional[bytes] = None
    video_name: str = "capture.webm"
    video_type: str = "video/webm"
    crop_meta: Optional[Dict[str, Any]] = None
    if video_file is not None:
        st.video(video_file)
        video_bytes = video_file.getvalue()
        video_name = video_file.name
        video_type = video_file.type or "video/mp4"
    elif captured_video and isinstance(captured_video, dict) and captured_video.get("data_base64"):
        video_bytes = base64.b64decode(captured_video["data_base64"])
        video_name = captured_video.get("filename") or "capture.webm"
        video_type = captured_video.get("mime") or "video/webm"
        st.info("Captured video ready. Click Analyze Video to send to API.")
        crop_meta = captured_video.get("crop") if isinstance(captured_video.get("crop"), dict) else None

    if video_bytes:
        if st.button("Analyze Video"):
            to_send_bytes = video_bytes
            to_send_name = video_name
            to_send_type = video_type
            to_send_crop = crop_meta

            needs_convert = bool(to_send_crop) or "webm" in (to_send_type or "").lower() or _guess_ext(
                to_send_name
            ) in {"webm", "mkv"}
            if needs_convert:
                with st.spinner("Converting capture to MP4 for API..."):
                    converted, conv_err = _convert_video_to_mp4(to_send_bytes, to_send_name, crop=to_send_crop)
                if conv_err or not converted:
                    st.error(conv_err or "Video conversion failed.")
                    st.stop()
                to_send_bytes = converted
                to_send_name = "capture.mp4"
                to_send_type = "video/mp4"
                to_send_crop = None

            st.caption(f"Video upload size: {len(to_send_bytes) / (1024 * 1024):.2f} MB")

            with st.spinner("Calling video API..."):
                payload, err = _post_video(
                    video_base,
                    to_send_bytes,
                    to_send_name,
                    to_send_type,
                    video_transcript,
                    float(target_fps),
                    None if max_frames == 0 else int(max_frames),
                    run_injection,
                    run_cross_modal,
                    run_caption,
                    run_vision_deepfake,
                    run_avsync,
                    log_frames,
                    crop=to_send_crop,
                )
            if err:
                st.error(err)
            else:
                st.success("Video analysis complete")
                st.json(payload.get("summary", {}))
                st.subheader("Top Risky Frames")
                st.json(payload.get("top_risky_frames_flat", []))
                st.subheader("Timeline (flat)")
                st.json(payload.get("timeline_flat", []))
                if extract_audio:
                    if not audio_api_key:
                        st.error("Audio API key required for audio extraction.")
                    else:
                        audio_bytes, audio_err = _extract_audio_mp3_from_video(to_send_bytes, to_send_name)
                        if audio_err:
                            st.error(audio_err)
                        else:
                            with st.spinner("Calling audio API on extracted audio..."):
                                audio_payload, audio_post_err = _post_audio(
                                    audio_base,
                                    audio_api_key,
                                    audio_bytes,
                                    extracted_audio_language,
                                    "mp3",
                                )
                            if audio_post_err:
                                st.error(audio_post_err)
                            else:
                                st.subheader("Extracted Audio Analysis")
                                st.json(audio_payload)

    with st.expander("Request Example (cURL)"):
        st.code(
            f"""curl -X POST "{video_base}/analyze_video" \\
  -F "video=@sample.mp4" \\
  -F "audio_transcript=..." \\
  -F "target_fps=5" \\
  -F "run_vision_deepfake=true" """,
            language="bash",
        )

with tab_debug:
    st.subheader("Debug & Diagnostics")
    st.markdown("Use this tab for quick health checks and timestamps.")
    col_a, col_b = st.columns(2)
    with col_a:
        if st.button("Check Audio Health"):
            ok, msg = _health_check(audio_base, "/health")
            st.write({"ok": ok, "info": msg})
    with col_b:
        if st.button("Check Image Health"):
            ok, msg = _health_check(image_base, "/")
            st.write({"ok": ok, "info": msg})

    col_c, col_d = st.columns(2)
    with col_c:
        if st.button("Check Video Health"):
            ok, msg = _health_check(video_base, "/")
            st.write({"ok": ok, "info": msg})
    with col_d:
        st.write("Local time:", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

    st.markdown(
        """
**Notes**
- If an endpoint times out, reduce video FPS or max frames.
- For audio, verify `x-api-key` is set correctly.
"""
    )
