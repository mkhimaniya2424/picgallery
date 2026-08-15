import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


# ---------------------------------------------------------------------------
# Chat Threads
# ---------------------------------------------------------------------------


class ChatThreadRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    connection_id: uuid.UUID
    last_message_at: datetime | None = None
    last_message_preview: str | None = None
    created_at: datetime
    updated_at: datetime

    # Resolved server-side — the other party's display name and avatar,
    # filled in by the route.
    other_party_name: str = ""
    other_party_avatar: str | None = None

    @classmethod
    def from_model(cls, thread, other_party_name: str = "", other_party_avatar: str | None = None) -> "ChatThreadRead":
        return cls(
            id=thread.id,
            connection_id=thread.connection_id,
            last_message_at=thread.last_message_at,
            last_message_preview=thread.last_message_preview,
            created_at=thread.created_at,
            updated_at=thread.updated_at,
            other_party_name=other_party_name,
            other_party_avatar=other_party_avatar,
        )


# ---------------------------------------------------------------------------
# Chat Messages
# ---------------------------------------------------------------------------


class ChatMessageCreate(BaseModel):
    """Body for POST /chat/threads/{id}/messages."""

    text: str = Field(min_length=1, max_length=5000)


class ChatMessageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    thread_id: uuid.UUID
    sender_id: uuid.UUID
    sender_role: str  # 'client' or 'photographer' — from User.role
    text: str
    is_read: bool
    created_at: datetime

    @classmethod
    def from_model(cls, message, sender_role: str = "") -> "ChatMessageRead":
        return cls(
            id=message.id,
            thread_id=message.thread_id,
            sender_id=message.sender_id,
            sender_role=sender_role,
            text=message.text,
            is_read=message.is_read,
            created_at=message.created_at,
        )


class ChatMessagesList(BaseModel):
    """Paginated response for GET /chat/threads/{id}/messages."""

    items: list[ChatMessageRead]
    total: int
    limit: int
    offset: int

