import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.models.activity_log import ActivityType


class ActivityLogRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    type: ActivityType
    title: str
    subtitle: str
    created_at: datetime


class ActivityLogList(BaseModel):
    """Paginated response for GET /activity-log — same offset/limit
    envelope as `ChatMessagesList` (`schemas/chat.py`).
    """

    items: list[ActivityLogRead]
    total: int
    limit: int
    offset: int
