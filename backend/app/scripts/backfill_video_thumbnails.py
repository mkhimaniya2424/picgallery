"""Generate missing poster-frame thumbnails for existing video records.

Run from the backend directory:

    python -m app.scripts.backfill_video_thumbnails

The operation is safe to repeat. It processes non-deleted videos whose
thumbnail is missing from the database or from local storage.
"""

from __future__ import annotations

import logging
from pathlib import Path

from sqlalchemy import select

from app.core.config import settings
from app.core.storage import make_video_thumbnail
from app.db.session import SessionLocal
from app.models.gallery import Media, MediaType
from app.models.user import User  # noqa: F401

logger = logging.getLogger(__name__)


def _local_thumbnail_exists(thumbnail_path: str | None) -> bool:
    return bool(
        thumbnail_path
        and (Path(settings.MEDIA_STORAGE_DIR) / thumbnail_path).is_file()
    )


def backfill() -> int:
    repaired = 0
    skipped = 0
    failed = 0

    with SessionLocal() as db:
        videos = db.execute(
            select(Media)
            .where(
                Media.media_type == MediaType.video,
                Media.is_deleted.is_(False),
            )
            .order_by(Media.created_at, Media.id)
        ).scalars()

        for media in videos:
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
                logger.error("Failed to generate thumbnail for %s", media.file_name)
                continue

            media.thumbnail_path = thumbnail_path
            db.commit()
            repaired += 1
            logger.info("Created %s", thumbnail_path)

    logger.info(
        "Finished video thumbnail backfill: repaired=%d skipped=%d failed=%d",
        repaired,
        skipped,
        failed,
    )
    return 1 if failed else 0


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    return backfill()


if __name__ == "__main__":
    raise SystemExit(main())
