"""Shared helpers for `AlbumClientShare` lookups.

Kept out of any single route module because both the studio-side
sharing endpoints (`api/routes/studio_shares.py`) and the client-side
read endpoints (`api/routes/client_gallery.py`) need the same "is this
album currently shared with this client" and "which albums does this
client currently have access to" logic — an active share always means
`revoked_at IS NULL`, and that rule should only be encoded once.
"""

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.album_share import AlbumClientShare


def is_shared_with(db: Session, *, album_id: uuid.UUID, client_id: uuid.UUID) -> bool:
    """True if `album_id` currently has an active (non-revoked) share
    with `client_id`.
    """
    stmt = select(AlbumClientShare.id).where(
        AlbumClientShare.album_id == album_id,
        AlbumClientShare.client_id == client_id,
        AlbumClientShare.revoked_at.is_(None),
    )
    return db.execute(stmt).first() is not None


def active_shares_for_client(db: Session, *, client_id: uuid.UUID) -> list[uuid.UUID]:
    """Every `album_id` currently shared (non-revoked) with `client_id`,
    across all studios. Callers that need it scoped to one studio
    filter the result (or query `AlbumClientShare` directly with an
    added `studio_id` predicate) rather than this helper taking on a
    second signature.
    """
    stmt = select(AlbumClientShare.album_id).where(
        AlbumClientShare.client_id == client_id,
        AlbumClientShare.revoked_at.is_(None),
    )
    return list(db.execute(stmt).scalars().all())