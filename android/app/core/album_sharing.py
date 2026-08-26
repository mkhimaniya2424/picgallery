"""Shared helpers for `AlbumClientShare` lookups.

Kept out of any single route module because both the studio-side
sharing endpoints (`api/routes/studio_shares.py`) and the client-side
read endpoints (`api/routes/client_gallery.py`) need the same "is this
album currently shared with this client" and "which albums does this
client currently have access to" logic — an active share always means
`revoked_at IS NULL`, and that rule should only be encoded once.

Public share link implicit access
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
A "public" share link (no password, not revoked, not expired) created by
a studio that the client has an *accepted* connection with is treated as
an implicit share — the client can see those albums in their Shared
Galleries without the studio having to add an explicit `AlbumClientShare`
row.  Both helpers below implement this rule so every downstream caller
(list_shared_studios, list_shared_folders, list_shared_albums, etc.) picks
it up automatically.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import and_, select
from sqlalchemy.orm import Session

from app.models.album_share import AlbumClientShare
from app.models.connection import ConnectionStatus, StudioClientConnection
from app.models.gallery import ShareLink


def _public_share_link_album_ids_for_connected_studios(
    db: Session, *, client_id: uuid.UUID
) -> list[uuid.UUID]:
    """Album ids reachable via a public (no-password, active, non-expired)
    share link from any studio the client has an accepted connection with.
    These are treated identically to an explicit AlbumClientShare row.
    """
    # Studios this client is connected to.
    connected_studio_ids = list(
        db.execute(
            select(StudioClientConnection.studio_id).where(
                StudioClientConnection.client_id == client_id,
                StudioClientConnection.status == ConnectionStatus.accepted,
            )
        ).scalars().all()
    )
    if not connected_studio_ids:
        return []

    now = datetime.now(timezone.utc)

    rows = db.execute(
        select(ShareLink.album_id).where(
            ShareLink.owner_id.in_(connected_studio_ids),
            ShareLink.is_revoked.is_(False),
            ShareLink.password_hash.is_(None),
            # expires_at IS NULL means never-expires; otherwise must be in the future.
            and_(
                ShareLink.expires_at.is_(None)
                | (ShareLink.expires_at > now)  # type: ignore[operator]
            ),
        )
    ).scalars().all()

    return list(rows)


def _public_share_link_album_ids_for_studio(
    db: Session, *, client_id: uuid.UUID, studio_id: uuid.UUID
) -> list[uuid.UUID]:
    """Like `_public_share_link_album_ids_for_connected_studios` but scoped
    to a single studio — used by per-studio access guards and folder/album
    listing to avoid loading all studios when only one is needed.
    """
    # Verify the client actually has an accepted connection to this studio.
    connected = db.execute(
        select(StudioClientConnection.id).where(
            StudioClientConnection.client_id == client_id,
            StudioClientConnection.studio_id == studio_id,
            StudioClientConnection.status == ConnectionStatus.accepted,
        )
    ).first()
    if connected is None:
        return []

    now = datetime.now(timezone.utc)

    rows = db.execute(
        select(ShareLink.album_id).where(
            ShareLink.owner_id == studio_id,
            ShareLink.is_revoked.is_(False),
            ShareLink.password_hash.is_(None),
            and_(
                ShareLink.expires_at.is_(None)
                | (ShareLink.expires_at > now)  # type: ignore[operator]
            ),
        )
    ).scalars().all()

    return list(rows)


def is_shared_with(db: Session, *, album_id: uuid.UUID, client_id: uuid.UUID) -> bool:
    """True if `album_id` currently has an active (non-revoked) explicit
    share with `client_id`, OR is accessible via a public share link from
    a studio the client is connected to.
    """
    # 1. Explicit per-album share row.
    stmt = select(AlbumClientShare.id).where(
        AlbumClientShare.album_id == album_id,
        AlbumClientShare.client_id == client_id,
        AlbumClientShare.revoked_at.is_(None),
    )
    if db.execute(stmt).first() is not None:
        return True

    # 2. Public share link implicit access.
    from app.models.gallery import Album  # local import to avoid circular

    album = db.get(Album, album_id)
    if album is None:
        return False

    public_ids = _public_share_link_album_ids_for_studio(
        db, client_id=client_id, studio_id=album.owner_id
    )
    return album_id in public_ids


def active_shares_for_client(db: Session, *, client_id: uuid.UUID) -> list[uuid.UUID]:
    """Every `album_id` currently accessible to `client_id`, across all
    studios — union of explicit AlbumClientShare rows and public share link
    albums from connected studios.

    Callers that need it scoped to one studio filter the result (or query
    `AlbumClientShare` / `ShareLink` directly with an added `studio_id`
    predicate) rather than this helper taking on a second signature.
    """
    # Explicit shares.
    explicit = set(
        db.execute(
            select(AlbumClientShare.album_id).where(
                AlbumClientShare.client_id == client_id,
                AlbumClientShare.revoked_at.is_(None),
            )
        ).scalars().all()
    )

    # Public share link implicit access via connected studios.
    implicit = set(
        _public_share_link_album_ids_for_connected_studios(db, client_id=client_id)
    )

    return list(explicit | implicit)