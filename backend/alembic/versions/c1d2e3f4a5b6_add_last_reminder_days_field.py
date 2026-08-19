"""add last_reminder_days field to users

Revision ID: c1d2e3f4a5b6
Revises: b4c5d6e7f8a9
Create Date: 2026-08-19 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c1d2e3f4a5b6'
down_revision: Union[str, None] = 'b4c5d6e7f8a9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Subscription expiry-reminder tracking. Stores the days-remaining
    # threshold (e.g. 30, 7, 1) the last reminder was sent for on the
    # user's CURRENT plan cycle, so send_plan_reminders.py never re-sends
    # the same threshold twice. pricing.php's activatePlan() already
    # writes/resets this column to NULL on every (re)activation — it
    # existed directly in the DB via manual SQL before this migration,
    # same as current_plan/plan_status/plan_expiry/trial_used were.
    # Nullable, no default needed: NULL simply means "no reminder sent
    # yet this cycle".
    op.add_column(
        'users',
        sa.Column('last_reminder_days', sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('users', 'last_reminder_days')
