import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class ActivityType(str, enum.Enum):
    """Mirrors the Flutter app's `ActivityType` enum
    (`models/admin_dashboard_data.dart`) exactly, so entries written
    here need no translation table on the client side.
    """

    upload = "upload"
    album = "album"
    client = "client"
    gallery = "gallery"
    profile = "profile"
    qr = "qr"
    report = "report"


class ActivityLog(Base):
    """One row in a studio's Activity Timeline — an automatically
    generated, append-only log of meaningful mutations (a media
    upload, a new client connection, a profile update, a
    gallery share, ...), newest first. This is the backend for the
    Admin "Recent Activity" screen (`recent_activity_screen.dart`),
    previously seeded in-memory by
    `InMemoryAdminDashboardRepository`'s fixed `ActivityEntry` list
    with no server component at all.

    Rows are written by `log_activity` (`app/core/activity_log.py`)
    from whichever route performed the underlying action, never
    edited afterwards — same "write-once, read-many" shape as
    `DownloadEvent`.

    `studio_id` is the owning studio (`users.id`, photographer role) —
    this timeline is a studio-only feature, there is no client-facing
    equivalent.
    """

    __tablename__ = "activity_log"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    studio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    type: Mapped[ActivityType] = mapped_column(Enum(ActivityType, name="activity_type"), nullable=False)
    title: Mapped[str] = mapped_column(String(150), nullable=False)
    subtitle: Mapped[str] = mapped_column(String(500), nullable=False, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)
