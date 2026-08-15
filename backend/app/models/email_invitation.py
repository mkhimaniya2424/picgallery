import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class EmailInvitation(Base):
    """Tracks a studio inviting an email address that has no PicGallery
    client account yet (Task: "Invite New Client" should work for
    non-users too, not just existing accounts — see
    `POST /connections/invite-by-email`).

    Purely a promise to auto-connect later: no `client_id` here since
    none exists yet. Once someone registers as a client with a matching
    `email`, `auth.register` turns every unconsumed row for that email
    into a real `StudioClientConnection` (pending, studio-initiated) and
    stamps `consumed_at` so it isn't applied twice.

    `UniqueConstraint` on (studio_id, email) mirrors
    `StudioClientConnection`'s (studio_id, client_id) constraint —
    re-inviting the same not-yet-registered email refreshes the same
    row (bumps `created_at`, resends the email) instead of piling up
    duplicates.
    """

    __tablename__ = "email_invitations"
    __table_args__ = (
        UniqueConstraint("studio_id", "email", name="uq_email_invitations_studio_email"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    studio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # Always lowercased/stripped before storing — see `_normalize_email`
    # in `connections.py` — so the lookup in `auth.register` is a plain
    # equality check.
    email: Mapped[str] = mapped_column(String(320), nullable=False, index=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    # Set once a matching signup consumes this invite and turns it into
    # a real connection. Left in the table (not deleted) as a history
    # trail of "this studio invited this email on this date" — cheap to
    # keep since the row is tiny.
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
