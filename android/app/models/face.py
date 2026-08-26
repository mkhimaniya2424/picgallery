import uuid
from datetime import datetime

from pgvector.sqlalchemy import Vector
from sqlalchemy import DateTime, Float, ForeignKey, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base

# insightface's buffalo_l model (ArcFace) produces 512-dimensional
# embeddings — this must match FaceAnalysis's output size in
# core/face_recognition.py and the pgvector column below.
FACE_EMBEDDING_DIM = 512


class FaceEmbedding(Base):
    """One detected face inside one Media photo. A group photo with 5
    faces gets 5 rows here, each with its own embedding — mirrors how
    `event_face_finder_api`'s `faces` Mongo collection worked, just
    moved into Postgres via pgvector so it lives alongside the rest of
    PicGallery's data instead of a separate MongoDB + FAISS index.

    `owner_id` is denormalized from `Media.owner_id` so a "search my
    whole library" query can filter directly on this table's most
    selective column without a join back to `media` first.

    Populated automatically in the background right after a photo is
    uploaded (see `media.py`'s `upload_media`), and can be rebuilt for
    already-uploaded photos via `POST /faces/reindex`.
    """

    __tablename__ = "face_embeddings"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    media_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("media.id", ondelete="CASCADE"), nullable=False, index=True
    )
    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    embedding: Mapped[list[float]] = mapped_column(Vector(FACE_EMBEDDING_DIM), nullable=False)

    # Pixel bounding box in the original photo: {"left","top","right","bottom"}
    box: Mapped[dict] = mapped_column(JSONB, nullable=False)
    detection_confidence: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
