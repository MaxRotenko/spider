import asyncio
import base64
import time
from enum import Enum, auto
from typing import Any, Dict

import cv2
import numpy as np
from fastapi import FastAPI
from pydantic import BaseModel

class AgentState(Enum):
    IDLE = auto()
    PERCEIVING = auto()
    MEASURING = auto()
    CHECKING = auto()

class SpiderEngine:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.state = AgentState.IDLE
        self.cooldown_seconds = config.get("cooldown_seconds", 2)
        self.last_frame_time = 0

    async def run_cycle(self, frame_b64: str, context: Dict[str, Any]) -> Dict[str, Any]:
        now = time.time()
        if now - self.last_frame_time < self.cooldown_seconds:
            return {"action": "none", "state": self.state.name, "reason": "cooldown"}
        self.last_frame_time = now

        try:
            img_data = base64.b64decode(frame_b64)
        except Exception:
            return {"error": "invalid base64"}

        nparr = np.frombuffer(img_data, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"error": "decode failed"}

        h, w = img.shape[:2]
        # Тут будет логика анализа — пока заглушка
        verdict = "pass"
        label = "Годен"
        color = "#00FF00"

        return {
            "verdict": verdict,
            "annotation": {
                "label": label,
                "color": color,
                "bbox": [0, 0, w, h]
            },
            "metrics": {
                "height_px": h,
                "width_px": w
            }
        }

app = FastAPI()
engine = SpiderEngine({})

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/measure/full")
async def measure_full(payload: Dict[str, Any]):
    frame_b64 = payload.get("frame_b64")
    context = payload.get("context", {})
    result = await engine.run_cycle(frame_b64, context)
    return result
