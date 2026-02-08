import os

import httpx
import streamlit as st

from src.engines.visual_engine import VisualSecurityEngine


SPACE_MODE = os.environ.get("SPACE_MODE", "").lower() in {"1", "true", "yes"}


@st.cache_resource
def get_engine() -> VisualSecurityEngine:
    return VisualSecurityEngine()


st.set_page_config(page_title="Visual Security Engine", layout="wide")
st.title("Visual Security Engine Demo")

uploaded = st.file_uploader("Upload an image", type=["png", "jpg", "jpeg", "webp"])
transcript = st.text_area("Audio transcript (optional)", value="a cat sitting on a ledge")

with st.sidebar:
    if not SPACE_MODE:
        st.header("API Settings")
        mode = st.selectbox("API mode", ["gateway", "split"], index=0)
        gateway_url = st.text_input("Gateway URL", value="http://localhost:8000")
        engine_d_url = st.text_input("Engine D URL", value="http://localhost:8001")
        engine_e_url = st.text_input("Engine E URL", value="http://localhost:8002")
        st.caption("Gateway mode calls a single API. Split mode calls D/E separately.")
    else:
        mode = "local"
    st.header("Performance")
    run_ocr = st.checkbox("Show OCR output", value=True)
    run_injection = st.checkbox("Run prompt-injection model", value=True)
    run_cross_modal = st.checkbox("Run cross-modal check", value=True)
    run_caption = st.checkbox("Run BLIP caption alignment", value=True)
    if run_injection and not run_ocr:
        st.info("OCR is required for prompt-injection. Enabling OCR display.")
        run_ocr = True

run_clicked = st.button("Run analysis", type="primary")

if run_clicked and not uploaded:
    st.warning("Please upload an image to continue.")

if run_clicked and uploaded:
    image_bytes = uploaded.read()
    st.image(image_bytes, caption="Uploaded image", use_container_width=True)

    with st.spinner("Calling APIs for analysis..."):
        text_payload = {}
        injection_result = {"skipped": True}
        cross_modal_result = {"skipped": True}

        if mode == "local":
            engine = get_engine()
            text_payload = engine.extract_text(image_bytes)
            injection_result = (
                engine.detect_injection_from_text(text_payload.get("normalized_text", ""))
                if run_injection
                else {"skipped": True}
            )
            if run_cross_modal:
                cross_modal_result = engine.check_cross_modal(image_bytes, transcript)
            else:
                cross_modal_result = {"skipped": True}
            ocr_vs_image = (
                engine.check_ocr_vs_image(image_bytes, text_payload.get("normalized_text", ""))
                if run_cross_modal
                else {"skipped": True}
            )
            caption_alignment = (
                engine.check_caption_alignment(image_bytes, text_payload.get("normalized_text", ""))
                if run_caption
                else {"skipped": True}
            )
            final_score = None
        elif mode == "gateway":
            try:
                response = httpx.post(
                    f"{gateway_url.rstrip('/')}/analyze",
                    files={"image": (uploaded.name, image_bytes, uploaded.type or "image/jpeg")},
                    data={
                        "audio_transcript": transcript,
                        "run_caption": str(run_caption).lower(),
                        "deep": str(run_injection).lower(),
                    },
                    timeout=300,
                )
                response.raise_for_status()
            except Exception as exc:
                st.error("Gateway API call failed. Is it running on the configured URL?")
                st.exception(exc)
                st.stop()
            payload = response.json()
            text_payload = payload.get("ocr", {})
            injection_result = payload.get("injection", {})
            cross_modal_result = payload.get("cross_modal", {})
            ocr_vs_image = payload.get("ocr_vs_image", {})
            caption_alignment = payload.get("caption_alignment", {})
            final_score = payload.get("final_score")
        else:
            if run_injection or run_ocr:
                try:
                    response_d = httpx.post(
                        f"{engine_d_url.rstrip('/')}/analyze_d",
                        files={"image": (uploaded.name, image_bytes, uploaded.type or "image/jpeg")},
                        data={"deep": str(run_injection).lower()},
                        timeout=300,
                    )
                    response_d.raise_for_status()
                except Exception as exc:
                    st.error("Engine D API call failed. Is it running on the configured URL?")
                    st.exception(exc)
                else:
                    payload_d = response_d.json()
                    text_payload = payload_d.get("ocr", {})
                    injection_result = payload_d.get("injection", {})

            if run_cross_modal:
                try:
                    response_e = httpx.post(
                        f"{engine_e_url.rstrip('/')}/analyze_e",
                        files={"image": (uploaded.name, image_bytes, uploaded.type or "image/jpeg")},
                        data={
                            "audio_transcript": transcript,
                            "ocr_text": text_payload.get("normalized_text", ""),
                            "run_caption": str(run_caption).lower(),
                        },
                        timeout=300,
                    )
                    response_e.raise_for_status()
                except Exception as exc:
                    st.error("Engine E API call failed. Is it running on the configured URL?")
                    st.exception(exc)
                else:
                    payload_e = response_e.json()
                    cross_modal_result = payload_e.get("cross_modal", {})
                    ocr_vs_image = payload_e.get("ocr_vs_image", {})
                    caption_alignment = payload_e.get("caption_alignment", {})
            else:
                ocr_vs_image = {"skipped": True}
                caption_alignment = {"skipped": True}
            final_score = None

        col1, col2 = st.columns(2)
        with col1:
            st.subheader("OCR Output")
            if not run_ocr:
                st.info("OCR display disabled.")
            else:
                st.text_area("Raw text", value=text_payload.get("raw_text", ""), height=150)
                st.text_area(
                    "Normalized text", value=text_payload.get("normalized_text", ""), height=120
                )

        with col2:
            st.subheader("Engine D: Prompt Injection")
            st.json(injection_result)
            st.subheader("Engine E: Cross-Modal Consistency")
            st.json(cross_modal_result)
            st.subheader("OCR vs Image (CLIP)")
            st.json(ocr_vs_image)
            st.subheader("Caption Alignment (BLIP)")
            st.json(caption_alignment)
            if final_score is not None:
                st.subheader("Final Risk Score")
                st.metric("final_score", final_score)
