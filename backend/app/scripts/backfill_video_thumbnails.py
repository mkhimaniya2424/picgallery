"""One-off backfill: generates missing video thumbnail JPEG files for
videos that were uploaded before thumbnail generation worked correctly,
AND updates the `thumbnail_path` column in the DB when it is blank.

Safe to re-run: only touches rows that are missing a physical thumbnail
file on disk. Per-row failures are logged and skipped.

Usage (from the `backend` directory, with the venv active):

    python -m app.scripts.backfill_video_thumbnails
    python -m app.scripts.backfill_video_thumbnails --dry-run
"""

import argparse
import logging
import subprocess
from pathlib import Path

from sqlalchemy import select

from app.core.config import settings
from app.core.storage import make_video_thumbnail
from app.db.session import SessionLocal
from app.models.gallery import Media, MediaType
from app.models.user import User  # noqa: F401  # needed for FK resolution

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


def backfill(dry_run: bool = False) -> None:
    media_root = Path(settings.MEDIA_STORAGE_DIR)
    db = SessionLocal()
    try:
        rows = db.execute(
            select(Media).where(Media.media_type == MediaType.video)
        ).scalars().all()

        if not rows:
            logger.info("No video rows found — nothing to do.")
            return

        logger.info("Found %d video row(s) to check.", len(rows))
        fixed = skipped = errors = 0

        for media in rows:
            if not media.file_path:
                logger.warning("  [SKIP] %s — no file_path", media.id)
                skipped += 1
                continue

            original_path = media_root / media.file_path
            if not original_path.exists():
                logger.warning("  [SKIP] %s — original file not found: %s", media.id, original_path)
                skipped += 1
                continue

            # Where we expect the thumbnail to live
            expected_thumb = original_path.parent / "thumbnail.jpg"

            if expected_thumb.exists():
                # Physical file exists — make sure DB has the path
                rel = str(expected_thumb.relative_to(media_root)).replace("\\", "/")
                if not media.thumbnail_path:
                    if not dry_run:
                        media.thumbnail_path = rel
                        db.commit()
                    logger.info("  [DB FIX] %s — thumb exists, updated DB path: %s", media.id, rel)
                    fixed += 1
                else:
                    logger.debug("  [OK] %s — thumbnail already exists.", media.id)
                    skipped += 1
                continue

            # Physical thumbnail is missing — generate it
            logger.info("  [GEN] %s  (%s)", media.id, media.file_name)

            if dry_run:
                logger.info("    → DRY RUN, skipping ffmpeg")
                skipped += 1
                continue

            try:
                result_path = make_video_thumbnail(
                    owner_id=media.owner_id,
                    media_id=media.id,
                    original_relative_path=media.file_path,
                )
                if result_path:
                    media.thumbnail_path = result_path
                    db.commit()
                    url = f"{settings.app_public_url}{settings.MEDIA_URL_PREFIX}/{result_path}"
                    logger.info("    ✅ Done! Verify: %s", url)
                    fixed += 1
                else:
                    logger.error("    ❌ make_video_thumbnail returned None (ffmpeg likely failed)")
                    errors += 1
            except Exception as exc:
                logger.exception("    ❌ Exception for %s: %s", media.id, exc)
                errors += 1

        logger.info("\nSummary: fixed=%d  skipped=%d  errors=%d", fixed, skipped, errors)
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Backfill missing video thumbnails")
    parser.add_argument("--dry-run", action="store_true",
                        help="Scan only — do not run ffmpeg or write to DB")
    args = parser.parse_args()
    backfill(dry_run=args.dry_run)
