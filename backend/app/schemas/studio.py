import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, field_validator


class StudioSummary(BaseModel):
    """Public-safe subset of a photographer ("Studio") account's
    profile — used anywhere a client browses or favorites a studio.
    Deliberately excludes private fields (`email`, `phone`, `address`)
    that `UserRead` exposes to the account owner itself.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    studio_name: str | None
    avatar_url: str | None
    cover_image_url: str | None = None
    business_type: str | None
    city: str | None
    state: str | None
    country: str | None
    bio: str | None
    specializations: list[str] | None = None
    studio_type: str | None = None
    experience_years: int | None = None
    pricing_min: float | None = None
    pricing_max: float | None = None
    # Showcase Portfolio thumbnails — not a plain column, so it doesn't
    # come through `model_validate` automatically like the other fields
    # here. Callers (see `_studio_summary()` in `api/routes/studios.py`)
    # attach this after the fact from a batch-loaded lookup.
    gallery_urls: list[str] = []

    @field_validator("specializations", mode="before")
    @classmethod
    def _split_csv(cls, value):
        # Same comma-separated-string-in-DB, list-to-client convention
        # `UserRead` uses.
        if isinstance(value, str):
            return [v.strip() for v in value.split(",") if v.strip()]
        return value


class StudioPortfolioImageRead(BaseModel):
    """One image in a studio's own Showcase Portfolio grid — returned by
    GET/POST `/studios/me/portfolio` (the studio managing its own
    profile, as opposed to `gallery_urls` above which is the read-only
    view a client sees on `StudioSummary`)."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    url: str


class AvatarUploadResponse(BaseModel):
    """Response for `POST /studios/me/avatar` and `POST /studios/me/cover`.
    Both endpoints only ever set one of these two fields — whichever one
    the endpoint is for — but returning both keeps the response shape
    identical for `studio_media_upload_service.dart` regardless of which
    endpoint it just called."""

    avatar_url: str | None = None
    cover_image_url: str | None = None


class FavoriteStudioRead(BaseModel):
    """One row of `GET /studios/favorites` — the favorited studio's
    public profile plus when this client favorited it."""

    studio: StudioSummary
    favorited_at: datetime


class StudioDirectoryItem(StudioSummary):
    """One row of `GET /studios` (the Discover Studios directory) — a
    `StudioSummary` plus this viewer's relationship to the studio.
    `connection_status`/`is_favorite` are always computed relative to
    the requesting client, never stored on the studio itself, so the
    same studio row looks different to different clients (mirrors how
    `ConnectionRead` only nests the *other* party's profile).
    """

    connection_status: str
    is_favorite: bool