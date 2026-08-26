"""Shared helper for writing Download History rows (Task 22).

Kept out of any single route module because two very different
endpoints need to log the same kind of event: an authenticated studio
downloading their own media (`api/routes/download_history.py`) and an
anonymous viewer downloading through a public Share Link
(`api/routes/share_links.py`). Both should produce identical
`DownloadEvent` rows, so the row-building logic lives here once.
"""

import uuid

from sqlalchemy.orm import Session

from app.models.gallery import DownloadEvent, DownloadSource, Media


def record_download_event(
    db: Session,
    *,
    media: Media,
    source: DownloadSource,
    downloaded_by_user_id: uuid.UUID | None = None,
    share_link_id: uuid.UUID | None = None,
    downloader_label: str | None = None,
) -> DownloadEvent:
    """Builds and stages (via `db.add`) one immutable Download History
    row snapshotted from `media`. Does NOT commit — callers commit
    alongside whatever else they're already doing in the same request
    (e.g. bumping `ShareLink.downloads_count`) so both writes land in a
    single transaction.
    """
    event = DownloadEvent(
        owner_id=media.owner_id,
        media_id=media.id,
        album_id=media.album_id,
        share_link_id=share_link_id,
        downloaded_by_user_id=downloaded_by_user_id,
        downloader_label=downloader_label,
        file_name=media.file_name,
        media_type=media.media_type,
        size_bytes=media.size_bytes,
        source=source,
    )
    db.add(event)
    return event
