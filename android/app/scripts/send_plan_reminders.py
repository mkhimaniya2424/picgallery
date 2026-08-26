"""Scans every user with an active subscription plan and sends an
expiry reminder as an in-app Notification row, once per threshold, per
plan cycle.

(Real push notifications are not wired up yet — this only creates the
in-app Notification row that the existing Notifications screen reads
via GET /notifications. Push can be added later without changing this
file's core logic, just by calling a send function alongside the
db.add(Notification(...)) below.)

Thresholds (days remaining):
    trial            -> [1]
    pro / premium    -> [30, 7, 1]

`User.last_reminder_days` tracks the most urgent (smallest) threshold
already reminded for on the CURRENT plan cycle. `pricing.php`'s
activatePlan() resets it to NULL every time a plan is (re)activated,
so a fresh cycle always starts able to send every threshold again.

Safe to re-run as often as you like (designed to run daily via cron —
see Step 5 for the exact crontab line): a threshold is only ever
reminded once per cycle, and per-user failures are logged and skipped
rather than aborting the whole run.

Usage (from the `backend` directory, with the venv active):

    python -m app.scripts.send_plan_reminders
    python -m app.scripts.send_plan_reminders --dry-run
"""

import argparse
import logging
import math
from datetime import datetime, timezone

from sqlalchemy import select

from app.core.firebase_service import send_push_notification
from app.db.session import SessionLocal

from app.models.notification import Notification, NotificationType
from app.models.user import User

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

# Ordered largest-first so "find the most urgent threshold reached" can
# just take the first match.
PLAN_REMINDER_THRESHOLDS: dict[str, list[int]] = {
    "trial": [1],
    "pro": [30, 7, 5, 1],
    "premium": [30, 7, 5, 1],
}


def _days_remaining(plan_expiry: datetime) -> int:
    """Same rounding as pricing.php's $daysUntilExpiry: ceil() so
    "23.1 hours left" still counts as 1 day remaining, not 0.
    """
    now = datetime.now(timezone.utc)
    if plan_expiry.tzinfo is None:
        now = now.replace(tzinfo=None)
    delta_seconds = (plan_expiry - now).total_seconds()
    return math.ceil(delta_seconds / 86400)


def _threshold_to_remind(plan: str, days_remaining: int, last_reminder_days: int | None) -> int | None:
    """Returns the threshold to send a reminder for right now, or None
    if nothing is due. Picks the most urgent (smallest) threshold the
    user has reached that hasn't already been sent this cycle.
    """
    thresholds = PLAN_REMINDER_THRESHOLDS.get(plan, [])
    reached = [t for t in thresholds if days_remaining <= t]
    if not reached:
        return None

    most_urgent = min(reached)

    # Already reminded for this threshold (or a more urgent one already
    # sent, which by definition covers this one too) this cycle.
    if last_reminder_days is not None and last_reminder_days <= most_urgent:
        return None

    return most_urgent


def _notification_copy(plan: str, days_remaining: int) -> tuple[str, str]:
    plan_label = {"trial": "Free Trial", "pro": "Pro", "premium": "Premium"}.get(plan, plan.title())
    if days_remaining <= 0:
        subtitle = f"Your {plan_label} plan expires today. Renew now to avoid interruption."
    elif days_remaining == 1:
        subtitle = f"Your {plan_label} plan expires tomorrow. Renew now to avoid interruption."
    else:
        subtitle = f"Your {plan_label} plan expires in {days_remaining} days. Renew now to avoid interruption."
    return "Subscription expiring soon", subtitle


def send_plan_reminders(dry_run: bool = False) -> None:
    db = SessionLocal()
    try:
        users = (
            db.execute(
                select(User).where(
                    User.plan_status == "active",
                    User.plan_expiry.is_not(None),
                    User.current_plan.is_not(None),
                )
            )
            .scalars()
            .all()
        )

        if not users:
            logger.info("Nothing to do — no users on an active plan.")
            return

        logger.info("Checking %d user(s) on an active plan.", len(users))

        reminded = 0
        skipped = 0
        for user in users:
            try:
                days_remaining = _days_remaining(user.plan_expiry)
                threshold = _threshold_to_remind(user.current_plan, days_remaining, user.last_reminder_days)

                if threshold is None:
                    skipped += 1
                    continue

                title, subtitle = _notification_copy(user.current_plan, days_remaining)

                logger.info(
                    "%s%s (%s) — %s plan, %d day(s) left, threshold=%d",
                    "[dry-run] " if dry_run else "",
                    user.id,
                    user.email,
                    user.current_plan,
                    days_remaining,
                    threshold,
                )

                if dry_run:
                    reminded += 1
                    continue

                db.add(
                    Notification(
                        user_id=user.id,
                        type=NotificationType.reminder,
                        title=title,
                        subtitle=subtitle,
                        data={
                            "current_plan": user.current_plan,
                            "days_remaining": days_remaining,
                            "threshold": threshold,
                        },
                    )
                )
                
                # Gated on the user's own push_notifications_enabled
                # preference; the in-app Notification row above is
                # unaffected.
                if user.fcm_token and user.push_notifications_enabled:
                    send_push_notification(
                        token=user.fcm_token,
                        title=title,
                        body=subtitle,
                        data={
                            "type": "reminder",
                            "current_plan": user.current_plan or "",
                            "days_remaining": str(days_remaining),
                        }
                    )


                user.last_reminder_days = threshold
                reminded += 1
            except Exception:
                # One bad row should never abort the whole run — the
                # DB session is rolled back for that user's change and
                # every other user is still processed normally.
                db.rollback()
                logger.exception("Failed to process reminder for user %s — skipped.", user.id)
                skipped += 1
                continue

        if not dry_run:
            db.commit()

        logger.info(
            "Done. %d reminded, %d skipped%s.",
            reminded,
            skipped,
            " (dry run — nothing was saved)" if dry_run else "",
        )
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would be sent without writing to the database or sending anything.",
    )
    args = parser.parse_args()
    send_plan_reminders(dry_run=args.dry_run)
