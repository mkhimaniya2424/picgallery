"""Real face detection + embedding extraction, backed by InsightFace.

This replaces the Flutter app's old fake `FaceRecognitionService` (which
hashed image bytes into a pseudo-embedding). The actual detection and
512-D ArcFace embedding now happen here, server-side, on CPU — the
same approach `event_face_finder_api` used, just moved into this
backend so embeddings live in Postgres (via pgvector) instead of a
separate MongoDB + FAISS index.

The `buffalo_l` model bundle is downloaded automatically by insightface
the first time `get_face_analyzer()` runs (~350MB, cached under
`~/.insightface/models`) — that first request will be slow; every
request after is fast.
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import TypedDict

import numpy as np
from fastapi import HTTPException

from app.core.config import settings

logger = logging.getLogger("app.face_recognition")


class DetectedFace(TypedDict):
    embedding: list[float]
    box: dict[str, int]
    confidence: float


_face_analyzer = None  # lazy singleton — see get_face_analyzer()


def get_face_analyzer():
    """Creates the CPU face model on first use, then reuses it for the
    lifetime of the process. Not created at import time so `uvicorn
    --reload` and simple `pytest` runs that never touch face search
    don't pay the model-load cost.
    """
    global _face_analyzer
    if _face_analyzer is None:
        from insightface.app import FaceAnalysis

        logger.info("Loading InsightFace buffalo_l model (first request only)…")
        _face_analyzer = FaceAnalysis(name="buffalo_l", providers=["CPUExecutionProvider"])
        _face_analyzer.prepare(ctx_id=0, det_size=(settings.FACE_DETECTION_SIZE, settings.FACE_DETECTION_SIZE))
    return _face_analyzer


def extract_faces(file_path: str | Path) -> list[DetectedFace]:
    """Detects every face in one image file and returns each one's
    pixel bounding box + L2-normalized 512-D embedding. Runs on CPU —
    callers should always invoke this via `run_in_threadpool` from an
    async route so it doesn't block the event loop.
    """
    import cv2

    image = cv2.imread(str(file_path))
    if image is None:
        raise HTTPException(422, "The image could not be read for face detection.")

    detected = get_face_analyzer().get(image)
    faces: list[DetectedFace] = []
    for face in detected:
        left, top, right, bottom = face.bbox.astype(int).tolist()
        embedding = face.embedding.astype(np.float32)
        norm = np.linalg.norm(embedding)
        if norm > 0:
            embedding = embedding / norm
        faces.append(
            {
                "embedding": embedding.tolist(),
                "box": {"left": left, "top": top, "right": right, "bottom": bottom},
                "confidence": float(getattr(face, "det_score", 1.0)),
            }
        )
    return faces


def cosine_similarity(a: list[float], b: list[float]) -> float:
    """Both embeddings are already L2-normalized by `extract_faces`, so
    this is just a dot product — kept as a real cosine calc anyway in
    case a caller ever passes in a non-normalized vector.
    """
    va, vb = np.asarray(a, dtype=np.float32), np.asarray(b, dtype=np.float32)
    na, nb = np.linalg.norm(va), np.linalg.norm(vb)
    if na == 0.0 or nb == 0.0:
        return 0.0
    return float(np.dot(va, vb) / (na * nb))
