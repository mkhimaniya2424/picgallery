"""add allow_downloads field to users

Revision ID: k6l7m8n9o0p1
Revises: j5k6l7m8n9o0
Create Date: 2026-07-23 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'k6l7m8n9o0p1'
down_revision: Union[str, None] = 'j5k6l7m8n9o0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Privacy & Security screen — "Download Permissions" toggle. Existing
    # rows default to True (downloads were always allowed before this
    # setting existed), matching the model's Python-side default.
    op.add_column(
        'users',
        sa.Column('allow_downloads', sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    # Drop the server default once existing rows are backfilled — new
    # inserts already supply the value via the SQLAlchemy model default.
    op.alter_column('users', 'allow_downloads', server_default=None)


def downgrade() -> None:
    op.drop_column('users', 'allow_downloads')
