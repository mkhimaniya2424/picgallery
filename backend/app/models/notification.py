import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class NotificationType(str, enum.Enum):
    """`reminder`/`approval`/`gallery` mirror the Flutter app's
    studio-side `NotificationType` enum in `admin_dashboard_data.dart`.
    `connection` and `system` are new — they cover client-side and
    account-level events (a new connection request, a studio being
    favorited, etc.) that don't fit those and aren't modeled on the
    Flutter side yet.
    """

    reminder = "reminder"
    approval = "approval"
    gallery = "gallery"
    connection = "connection"
    system = "system"


class Notification(Base):
    """A single in-app notification for either role.

    `user_id` is just a `users.id` row — same as `StudioFavorite`
    doesn't need separate client/studio tables since both roles are
    `User` rows, this one table backs both the Studio Notifications
    screen (`notifications_screen.dart`, currently backed by
    `adminDashboardProvider`'s in-memory `NotificationData`) and the
    Client Alerts tab (`NotificationAlert` in
    `notification_alert.dart`, currently Hive-only).

    `data` is a free-form JSONB payload for whatever the notification
    needs to deep-link to (a connection id, a gallery id, a booking
    id, ...) — kept generic rather than a rigid FK column per
    notification type, since the set of possible targets is
    open-ended and heterogeneous, the same reasoning `Media.edit_recipe`
    uses JSONB for.
    """

    __tablename__ = "notifications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    type: Mapped[NotificationType] = mapped_column(
        Enum(NotificationType, name="notification_type"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(150), nullable=False)
    subtitle: Mapped[str] = mapped_column(String(500), nullable=False)
    data: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), index=True)
