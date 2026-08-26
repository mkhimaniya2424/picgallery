import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class ConnectionStatus(str, enum.Enum):
    """Mirrors the subset of the Flutter app's `ConnectionStatus` enum
    (`studio_client_connection_model.dart`) that the backend actually
    tracks. `pending`/`accepted`/`declined` map 1:1; the Flutter-only
    `notConnected` isn't a real state (it's what the app shows when no
    row exists at all), and `blocked` isn't wired up on the client yet
    so it's left out here too rather than modeling something nothing
    uses. `pendingClientRequest` vs `pendingStudioRequest` isn't a
    separate DB state either — it's `pending` + `initiated_by`, same
    idea as `Notification.data` staying generic instead of one column
    per case.
    """

    pending = "pending"
    accepted = "accepted"
    declined = "declined"


class ConnectionInitiator(str, enum.Enum):
    """Who sent the invite — mirrors `initiatedBy` ('client'/'studio')
    on the Flutter side, kept as a real enum here instead of a free
    string.
    """

    studio = "studio"
    client = "client"


class StudioClientConnection(Base):
    """A studio<->client relationship — invited by one side, accepted
    or declined by the other. Purely a join between two `User` rows
    (`studio_id` always a photographer-role account, `client_id`
    always a client-role account), same convention as `StudioFavorite`:
    enforced in the route layer, not by a DB constraint.

    `UniqueConstraint` keeps a single row per (studio, client) pair —
    re-inviting after a decline updates that same row (status back to
    `pending`) rather than creating a second one, so history isn't
    scattered across duplicate rows.
    """

    __tablename__ = "studio_client_connections"
    __table_args__ = (
        UniqueConstraint(
            "studio_id", "client_id", name="uq_studio_client_connections_studio_client"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    studio_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    client_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    status: Mapped[ConnectionStatus] = mapped_column(
        Enum(ConnectionStatus, name="connection_status"),
        nullable=False,
        default=ConnectionStatus.pending,
    )
    initiated_by: Mapped[ConnectionInitiator] = mapped_column(
        Enum(ConnectionInitiator, name="connection_initiator"), nullable=False
    )

    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
