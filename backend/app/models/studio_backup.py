import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class StudioBackup(Base):
    """A single settings-backup snapshot for a studio (Task 6 — Backup &
    Restore). `owner_id` is always a photographer-role `User` row —
    enforced in the route layer (`get_current_studio_user` in
    `api/routes/studios.py`), same pattern as `StudioPortfolioImage.owner_id`.

    `payload` is the studio's settings blob as sent by the app (there is
    no dedicated settings table server-side today — settings live in the
    app's local Hive store — so this just stores whatever JSON the
    client posts), same free-form-JSONB reasoning `Notification.data`
    and `Media.edit_recipe` use.

    One row is written per `POST /studios/me/backup` call rather than
    upserting a single row, so history/versioning is available later if
    needed; `GET /studios/me/backup` (Task 6.3) just reads the most
    recent row (`ORDER BY created_at DESC LIMIT 1`) for "latest backup".
    """

    __tablename__ = "studio_backups"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    payload: Mapped[dict] = mapped_column(JSONB, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)