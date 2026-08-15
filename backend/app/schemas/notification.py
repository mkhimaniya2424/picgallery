import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.notification import NotificationType


class NotificationRead(BaseModel):
    """One notification row for the current user — backs both the
    Client "Alerts" tab (`NotificationAlert` in `notification_alert.dart`,
    previously Hive-only) and the Studio Notifications screen
    (`notifications_screen.dart`), same dual-purpose table the
    `Notification` model docstring describes.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    type: NotificationType
    title: str
    subtitle: str
    data: dict | None = None
    is_read: bool
    created_at: datetime
