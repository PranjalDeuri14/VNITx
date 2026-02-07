import io
import re
import urllib.request
from typing import Any, Dict, Iterable, List, Tuple, Union

import numpy as np
from PIL import Image
from paddleocr import PaddleOCR
from sentence_transformers import SentenceTransformer


THREAT_DICTIONARY = [
    "ignore previous",
    "system override",
    "transfer funds",
    "bypass safety",
    "disable guardrails",
    "override policy",
    "reveal secrets",
]


class VisualSecurityEngine:
    def __init__(self) -> None:
        self.ocr = PaddleOCR(use_textline_orientation=True, lang="en")
        self.clip = SentenceTransformer("clip-ViT-B-32")

    @staticmethod
    def _normalize_text(text: str) -> str:
        lowered = text.lower()
        cleaned = re.sub(r"[^a-z0-9]+", " ", lowered)
        tokens = cleaned.split()

        def merge_single_letter_runs(items: Iterable[str]) -> List[str]:
            merged: List[str] = []
            run: List[str] = []
            for token in items:
                if len(token) == 1:
                    run.append(token)
                    continue
                if run:
                    merged.append("".join(run))
                    run = []
                merged.append(token)
            if run:
                merged.append("".join(run))
            return merged

        merged_tokens = merge_single_letter_runs(tokens)
        return " ".join(merged_tokens)

    @staticmethod
    def _load_image_for_ocr(image: Union[str, bytes]) -> Union[str, np.ndarray]:
        if isinstance(image, str):
            return image
        pil_image = Image.open(io.BytesIO(image)).convert("RGB")
        rgb = np.array(pil_image)
        return rgb[:, :, ::-1]

    @staticmethod
    def _load_image_for_clip(image: Union[str, bytes]) -> Image.Image:
        if isinstance(image, str):
            return Image.open(image).convert("RGB")
        return Image.open(io.BytesIO(image)).convert("RGB")

    @staticmethod
    def _extract_ocr_text(ocr_result: List[Any]) -> Tuple[str, List[Tuple[str, float]]]:
        fragments: List[str] = []
        scored: List[Tuple[str, float]] = []
        for block in ocr_result or []:
            if not block:
                continue
            # PaddleOCR result formats can vary across versions.
            for line in block:
                if not line:
                    continue
                text: str | None = None
                score: float | None = None
                if isinstance(line, (list, tuple)) and len(line) >= 2:
                    meta = line[1]
                    if isinstance(meta, (list, tuple)):
                        if meta:
                            text = str(meta[0])
                        if len(meta) > 1 and isinstance(meta[1], (float, int)):
                            score = float(meta[1])
                    elif isinstance(meta, str):
                        text = meta
                elif isinstance(line, str):
                    text = line

                if text:
                    fragments.append(text)
                    if score is not None:
                        scored.append((text, score))
        return " ".join(fragments), scored

    def detect_injection(self, image: Union[str, bytes]) -> Dict[str, Any]:
        ocr_input = self._load_image_for_ocr(image)
        ocr_result = self.ocr.ocr(ocr_input)
        raw_text, scored = self._extract_ocr_text(ocr_result)

        normalized = self._normalize_text(raw_text)
        matched = [phrase for phrase in THREAT_DICTIONARY if phrase in normalized]

        if not normalized:
            return {
                "is_threat": False,
                "risk_score": 0.0,
                "reason": "No readable text detected in image.",
            }

        if matched:
            avg_conf = float(np.mean([score for _, score in scored])) if scored else 0.6
            risk = min(1.0, 0.6 + 0.1 * len(matched) + 0.2 * avg_conf)
            return {
                "is_threat": True,
                "risk_score": round(risk, 3),
                "reason": f"Matched threat phrases: {', '.join(sorted(set(matched)))}.",
            }

        return {
            "is_threat": False,
            "risk_score": 0.0,
            "reason": "No threat phrases detected.",
        }

    def check_cross_modal(self, image: Union[str, bytes], audio_transcript: str) -> Dict[str, Any]:
        if not audio_transcript:
            return {"is_mismatch": True, "consistency_score": 0.0}

        pil_image = self._load_image_for_clip(image)
        image_emb = self.clip.encode([pil_image], normalize_embeddings=True)
        text_emb = self.clip.encode([audio_transcript], normalize_embeddings=True)
        similarity = float(np.dot(image_emb[0], text_emb[0]))

        return {
            "is_mismatch": similarity < 0.18,
            "consistency_score": round(similarity, 4),
        }


def _download_demo_image() -> bytes:
    demo_urls = [
        "https://upload.wikimedia.org/wikipedia/commons/3/3a/Cat03.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/7/74/A-Cat.jpg",
    ]
    headers = {"User-Agent": "Mozilla/5.0 (Sentinel-X demo)"}
    last_error: Exception | None = None
    for url in demo_urls:
        try:
            request = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(request, timeout=20) as response:
                return response.read()
        except Exception as exc:  # pragma: no cover - best effort demo download
            last_error = exc
            continue
    raise RuntimeError(f"Failed to download demo image: {last_error}")


if __name__ == "__main__":
    demo_bytes = _download_demo_image()

    engine = VisualSecurityEngine()
    injection_result = engine.detect_injection(demo_bytes)
    cross_modal_result = engine.check_cross_modal(demo_bytes, "a cat sitting on a ledge")

    print("Injection detection:", injection_result)
    print("Cross-modal consistency:", cross_modal_result)
