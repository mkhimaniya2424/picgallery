from pydantic import BaseModel

from app.schemas.gallery import MediaRead


class FaceBoxRead(BaseModel):
    left: int
    top: int
    right: int
    bottom: int


class DetectedFaceRead(BaseModel):
    """One face found in the *query selfie* (not a gallery photo). The
    client shows these as selectable crops when a selfie has more than
    one face — `face_index` is what to pass back to `/faces/search` on
    the follow-up call once the person picks one.
    """

    face_index: int
    box: FaceBoxRead
    confidence: float


class FaceMatchRead(BaseModel):
    media: MediaRead
    similarity: float  # 0.0-1.0 cosine similarity against the query face


class FaceSearchResponse(BaseModel):
    detected_faces: list[DetectedFaceRead]
    # Which face_index the search actually ran with (defaults to the
    # largest face when the caller doesn't specify one).
    searched_face_index: int | None
    matches: list[FaceMatchRead]


class FaceIndexStatusRead(BaseModel):
    total_photos: int
    indexed_photos: int
    total_faces: int
