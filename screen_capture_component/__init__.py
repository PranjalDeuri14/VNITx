from __future__ import annotations

import os
from typing import Any, Dict, Optional

import streamlit.components.v1 as components

_FRONTEND_DIR = os.path.join(os.path.dirname(__file__), "frontend")

_component = components.declare_component("screen_capture_component", path=_FRONTEND_DIR)


def screen_capture(
    *,
    key: str,
    max_seconds: int = 10,
    fps: int = 20,
    video_bits_per_second: int = 1_500_000,
) -> Optional[Dict[str, Any]]:
    """
    Browser-based tab/window/screen capture + crop + record.

    Returns a dict like:
      {
        "data_base64": "...",
        "mime": "video/webm;codecs=vp9",
        "filename": "screen_capture.webm"
      }
    """

    return _component(
        key=key,
        max_seconds=int(max_seconds),
        fps=int(fps),
        video_bits_per_second=int(video_bits_per_second),
        default=None,
    )

