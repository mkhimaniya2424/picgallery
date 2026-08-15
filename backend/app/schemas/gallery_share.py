import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


# ---------------------------------------------------------------------------
# Studio-side (creating / listing / revoking shares)
# ---------------------------------------------------------------------------


class AlbumShareCreate(BaseModel):
    album_id: uuid.UUID
    client_id: uuid.UUID


class FolderShareCreate(BaseModel):
    folder_id: uuid.UUID
    client_id: uuid.UUID


class AlbumClientShareRead(BaseModel):
    """A single share row, as the studio sees it — used by `POST
    /studio/shares`, `POST /studio/shares/folder`, and `GET
    /studio/shares` (the future "manage sharing" screen).
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    album_id: uuid.UUID
    client_id: uuid.UUID
    studio_id: uuid.UUID
    shared_at: datetime
    revoked_at: datetime | None

    # Denormalized for display so the "manage sharing" screen doesn't
    # need a second round-trip per row to show what's actually shared.
    album_name: str | None = None
    album_cover_thumbnail_url: str | None = None

    @classmethod
    def from_model(
        cls,
        share,
        album_name: str | None = None,
        album_cover_thumbnail_url: str | None = None,
    ) -> "AlbumClientShareRead":
        return cls(
            id=share.id,
            album_id=share.album_id,
            client_id=share.client_id,
            studio_id=share.studio_id,
            shared_at=share.shared_at,
            revoked_at=share.revoked_at,
            album_name=album_name,
            album_cover_thumbnail_url=album_cover_thumbnail_url,
        )


class BulkShareResult(BaseModel):
    """Response for `POST /studio/shares/folder` — a folder can contain
    many albums, some of which may already be actively shared with this
    client, so the response distinguishes newly-created rows from ones
    that were already active rather than silently deduplicating.
    """

    shares: list[AlbumClientShareRead]
    created_count: int
    already_shared_count: int


# ---------------------------------------------------------------------------
# Client-side (read-only browsing of what's been shared with them)
# ---------------------------------------------------------------------------


class SharedStudioRead(BaseModel):
    """One studio in the client's Shared Studios list — a studio only
    appears here once it has at least one active share with this
    client, regardless of connection status.
    """

    id: uuid.UUID
    name: str
    logo_url: str | None
    shared_count: int


class SharedFolderRead(BaseModel):
    """A folder node in the client's pruned folder tree — only folders
    that (directly or via a descendant) contain at least one album
    actively shared with this client appear at all.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    parent_id: uuid.UUID | None
    gradient_argb: list[int] = Field(default_factory=list)

    # Count of shared albums directly inside this folder (not counting
    # descendants) — mirrors `FolderRead.album_count`'s "computed, never
    # stored" convention, just scoped to this client's visible slice.
    shared_album_count: int = 0