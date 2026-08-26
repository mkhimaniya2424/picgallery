import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AlbumClientShare(Base):
    """A studio sharing one Album with one client — powers the read-only
    Client Gallery (studio picks specific albums/folders a given client
    can see, instead of the client seeing everything the studio owns).

    `studio_id` is stored alongside `album_id`/`client_id` even though
    it's derivable via `Album.owner_id` — same reasoning as
    `StudioClientConnection` storing both sides directly: every read
    endpoint below filters by studio, and denormalizing here avoids a
    join through `albums` on every request.

    Revocation is soft (`revoked_at`), never a hard delete — same
    convention as `StudioClientConnection`/`ShareLink`: history stays
    queryable (e.g. for a future "shared with X on <date>, revoked on
    <date>" audit trail) and a re-share after revoke can be told apart
    from a share that was never revoked.

    `UniqueConstraint` is scoped to the *active* pairing conceptually,
    but Postgres can't do a partial unique constraint through plain
    SQLAlchemy table args here, so uniqueness is enforced in the route
    layer instead (find-or-reactivate an existing row for the pair
    rather than inserting a duplicate) — same pattern as
    `StudioFavorite`'s route-level idempotency check.
    """

    __tablename__ = "album_client_shares"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    album_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("albums.id", ondelete="CASCADE"), nullable=False, index=True
    )
    client_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    studio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    shared_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)