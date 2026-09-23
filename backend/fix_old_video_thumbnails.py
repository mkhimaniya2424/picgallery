"""Generate missing poster-frame thumbnails for previously uploaded videos.

Run this from the backend directory after installing the backend dependencies:

    python fix_old_video_thumbnails.py

The script updates only non-deleted video records whose thumbnail is missing
from the database. It is safe to run more than once.
"""

from __future__ import annotations

import logging
from pathlib import Path

from sqlalchemy import select

from app.core.config import settings
from app.core.storage import make_video_thumbnail
from app.db.session import SessionLocal
# Register all model tables before SQLAlchemy resolves Media's foreign keys.
import app.models  # noqa: F401
from app.models.gallery import Media, MediaType

logger = logging.getLogger("fix_old_video_thumbnails")


def _local_thumbnail_exists(thumbnail_path: str | None) -> bool:
    if not thumbnail_path:
        return False
    return (Path(settings.MEDIA_STORAGE_DIR) / thumbnail_path).is_file()


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    repaired = 0
    skipped = 0
    failed = 0

    with SessionLocal() as db:
        videos = db.execute(
            select(Media)
            .where(Media.media_type == MediaType.video, Media.is_deleted.is_(False))
            .order_by(Media.created_at, Media.id)
        ).scalars()

        for media in videos:
            # R2 objects are addressed by their database key, so a recorded
            # thumbnail is considered present there. Local storage can verify
            # the file directly and will repair orphaned database references.
            if media.thumbnail_path and (
                settings.STORAGE_BACKEND != "local"
                or _local_thumbnail_exists(media.thumbnail_path)
            ):
                skipped += 1
                continue

            logger.info("Generating thumbnail for %s (%s)", media.file_name, media.id)
            thumbnail_path = make_video_thumbnail(
                owner_id=media.owner_id,
                media_id=media.id,
                original_relative_path=media.file_path,
            )
            if thumbnail_path is None:
                failed += 1
                logger.error("Could not generate thumbnail for %s (%s)", media.file_name, media.id)
                continue

            media.thumbnail_path = thumbnail_path
            db.commit()
            repaired += 1

    logger.info("Finished: repaired=%d skipped=%d failed=%d", repaired, skipped, failed)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
