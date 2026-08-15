import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class StudioFavorite(Base):
    """A client's "favorited" studio (Task 3 — Favorite Studios screen).
    Purely a join between two `User` rows: `client_id` is always a
    client-role account and `studio_id` always a photographer-role
    account — enforced in the route layer (`get_current_client_user` /
    `_get_studio_or_404` in `api/routes/studios.py`), not by a DB
    constraint, same as how gallery-ownership roles are checked
    elsewhere rather than modeled with separate tables per role.

    `UniqueConstraint` makes favoriting idempotent at the DB level; the
    route also checks first so a repeat `POST .../favorite` is a no-op
    that returns the existing row rather than a 500 from a constraint
    violation.
    """

    __tablename__ = "studio_favorites"
    __table_args__ = (
        UniqueConstraint("client_id", "studio_id", name="uq_studio_favorites_client_studio"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    client_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    studio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
