import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models.connection import ConnectionInitiator, ConnectionStatus
from app.schemas.studio import StudioSummary


class ClientSummary(BaseModel):
    """Public-safe subset of a client account's profile — the client-side
    counterpart to `StudioSummary`, shown to a studio browsing its
    connections. Excludes `email`/`phone`/`address` same as
    `StudioSummary` excludes them for studios.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    full_name: str
    avatar_url: str | None
    city: str | None
    state: str | None
    country: str | None
    bio: str | None
    preferred_photo_types: list[str] | None = None

    @field_validator("preferred_photo_types", mode="before")
    @classmethod
    def _split_csv(cls, value):
        if isinstance(value, str):
            return [v.strip() for v in value.split(",") if v.strip()]
        return value


class ConnectionInviteCreate(BaseModel):
    """Payload for POST /connections/invite — studio-only. Invites a
    client by id.
    """

    client_id: uuid.UUID


class ConnectionInviteByEmailCreate(BaseModel):
    """Payload for POST /connections/invite-by-email — studio-only.
    Unlike [ConnectionInviteCreate] (which needs an existing client's
    id), this accepts a raw email address and works whether or not that
    email already has a PicGallery client account: see
    `invite_client_by_email` in `connections.py`.
    """

    email: EmailStr


class ClientLookupRead(BaseModel):
    """Result of GET /connections/lookup-client — just enough for the
    Invite New Client form to resolve an email address the studio
    typed in to an existing client's id before calling
    `POST /connections/invite`, which only accepts `client_id`. There is
    no client-creation endpoint (accounts only ever come from
    registration), so this is a lookup, not an invite-by-email.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    full_name: str


class ConnectionRead(BaseModel):
    """One connection row, from the current user's point of view. Only
    the *other* party's profile is nested — a studio calling
    `GET /connections` sees `client`, a client sees `studio`; whichever
    side isn't the viewer is always populated, the other is always
    `None`, rather than requiring the caller to know which id is theirs.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    status: ConnectionStatus
    initiated_by: ConnectionInitiator
    requested_at: datetime
    responded_at: datetime | None
    studio: StudioSummary | None = None
    client: ClientSummary | None = None


class ConnectionInviteResult(BaseModel):
    """Response for POST /connections/invite-by-email — one of two
    shapes depending on whether the email matched an existing client
    account:

    - `status="connected"`: matched an existing account; `connection`
      is the resulting row (same shape `POST /connections/invite`
      always returned), `email` is `None`.
    - `status="invited_pending_signup"`: no account exists yet; an
      `EmailInvitation` was recorded and a signup email sent instead.
      `connection` is `None` (nothing to show yet — it becomes a real
      pending connection the moment that email registers), and `email`
      echoes back the (normalized) address that was invited.
    """

    status: Literal["connected", "invited_pending_signup"]
    connection: ConnectionRead | None = None
    email: str | None = None