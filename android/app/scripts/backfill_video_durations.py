"""One-off backfill: fills in `Media.duration_ms` for videos uploaded
before duration extraction existed (see `core/storage.get_video_duration_ms`,
wired into `POST /media/upload` for new uploads only — this script
covers everything uploaded before that change).

Safe to re-run: only touches rows where `duration_ms IS NULL`, and
per-row failures (missing file, ffprobe error) are logged and skipped
rather than aborting the whole run.

Usage (from the `backend` directory, with the venv active):

    python -m app.scripts.backfill_video_durations
    python -m app.scripts.backfill_video_durations --dry-run
"""
"""One-off backfill: fills in `Media.duration_ms` for videos uploaded
before duration extraction existed (see `core/storage.get_video_duration_ms`,
wired into `POST /media/upload` for new uploads only — this script
covers everything uploaded before that change).

Safe to re-run: only touches rows where `duration_ms IS NULL`, and
per-row failures (missing file, ffprobe error) are logged and skipped
rather than aborting the whole run.

Usage (from the `backend` directory, with the venv active):

    python -m app.scripts.backfill_video_durations
    python -m app.scripts.backfill_video_durations --dry-run
"""

import argparse
import logging

from sqlalchemy import select

from app.core.storage import get_video_duration_ms
from app.db.session import SessionLocal

from app.models.gallery import Media, MediaType

# Side-effect import: `Media.owner_id` has a ForeignKey("users.id"), so the
# User model must be registered on the declarative Base before we flush/
# commit, or SQLAlchemy can't resolve the FK and raises NoReferencedTableError.
# `app/models/__init__.py` is currently empty, so this has to be explicit.
from app.models.user import User  # noqa: F401

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


def backfill(dry_run: bool = False) -> None:
    db = SessionLocal()
    try:
        rows = db.execute(
            select(Media).where(
                Media.media_type == MediaType.video,
                Media.duration_ms.is_(None),
            )
        ).scalars().all()

        if not rows:
            logger.info("Nothing to do — every video already has a duration.")
            return

        logger.info("Found %d video(s) missing duration_ms.", len(rows))

        updated = 0
        failed = 0
        for media in rows:
            duration_ms = get_video_duration_ms(media.file_path)
            if duration_ms is None:
                failed += 1
                logger.warning(
                    "Skipped %s (%s) — ffprobe couldn't read a duration.",
                    media.id,
                    media.file_name,
                )
                continue

            logger.info(
                "%s%s (%s) -> %dms",
                "[dry-run] " if dry_run else "",
                media.id,
                media.file_name,
                duration_ms,
            )
            if not dry_run:
                media.duration_ms = duration_ms
            updated += 1

        if not dry_run:
            db.commit()

        logger.info(
            "Done. %d updated, %d skipped%s.",
            updated,
            failed,
            " (dry run — nothing was saved)" if dry_run else "",
        )
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would change without writing to the database.",
    )
    args = parser.parse_args()
    backfill(dry_run=args.dry_run)
import argparse
import logging

from sqlalchemy import select

from app.core.storage import get_video_duration_ms
from app.db.session import SessionLocal

# Side-effect import: `Media.owner_id` has a ForeignKey("users.id"), so the
# User model must be registered on the declarative Base before we flush/
# commit, or SQLAlchemy can't resolve the FK and raises NoReferencedTableError.
# `app.models.gallery` alone does NOT pull User in — importing the package
# does (assuming app/models/__init__.py imports User there). If it doesn't,
# swap this for the explicit path, e.g. `from app.models.user import User`.
import app.models  # noqa: F401

from app.models.gallery import Media, MediaType

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


def backfill(dry_run: bool = False) -> None:
    db = SessionLocal()
    try:
        rows = db.execute(
            select(Media).where(
                Media.media_type == MediaType.video,
                Media.duration_ms.is_(None),
            )
        ).scalars().all()

        if not rows:
            logger.info("Nothing to do — every video already has a duration.")
            return

        logger.info("Found %d video(s) missing duration_ms.", len(rows))

        updated = 0
        failed = 0
        for media in rows:
            duration_ms = get_video_duration_ms(media.file_path)
            if duration_ms is None:
                failed += 1
                logger.warning(
                    "Skipped %s (%s) — ffprobe couldn't read a duration.",
                    media.id,
                    media.file_name,
                )
                continue

            logger.info(
                "%s%s (%s) -> %dms",
                "[dry-run] " if dry_run else "",
                media.id,
                media.file_name,
                duration_ms,
            )
            if not dry_run:
                media.duration_ms = duration_ms
            updated += 1

        if not dry_run:
            db.commit()

        logger.info(
            "Done. %d updated, %d skipped%s.",
            updated,
            failed,
            " (dry run — nothing was saved)" if dry_run else "",
        )
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would change without writing to the database.",
    )
    args = parser.parse_args()
    backfill(dry_run=args.dry_run)