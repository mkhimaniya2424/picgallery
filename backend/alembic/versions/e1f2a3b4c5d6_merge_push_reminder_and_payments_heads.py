"""merge push/reminder branch with payments branch

This merges the two divergent alembic heads that resulted from
parallel feature work off z0a1b2c3d4e5 (create_album_client_shares_table):

  - f2a3b4c5d6e7 (reshape_studio_backups_to_history_model, tip of the
    branch actually applied to the live DB: ... -> d5e6f7a8b9c0
    create_studio_backups_table -> f2a3b4c5d6e7 reshape)
  - c1d2e3f4a5b6 (add_last_reminder_days_field, tip of the sibling
    branch: ... -> b4c5d6e7f8a9 add_website_field -> c1d2e3f4a5b6)

CORRECTION (2026-08-19): an earlier version of this merge pointed at
h1i2j3k4l5m6 instead of f2a3b4c5d6e7/d5e6f7a8b9c0, based on comparing
migration files against the live SQLAlchemy model. That was wrong —
`alembic upgrade head` failed with "Can't locate revision identified
by 'd5e6f7a8b9c0'", proving the DB's real alembic_version was
d5e6f7a8b9c0, i.e. THAT branch was the one actually applied, not
h1i2j3k4l5m6 (which was never run against this DB and has been
deleted as the true orphan). f2a3b4c5d6e7 was added on top of
d5e6f7a8b9c0 to reshape the table to match the live model instead of
discarding applied history.

This is a no-op merge itself: no schema changes, just joins the two
heads into one so `alembic upgrade head` has a single unambiguous
target again.

Revision ID: e1f2a3b4c5d6
Revises: f2a3b4c5d6e7, c1d2e3f4a5b6
Create Date: 2026-08-19 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e1f2a3b4c5d6'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Merge revision — combines both parent heads. Alembic represents this
# as a tuple on down_revision rather than the single-string form used
# by every other migration in this history.
down_revision = ('f2a3b4c5d6e7', 'c1d2e3f4a5b6')


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass