"""add app_language field to users

Revision ID: s3t4u5v6w7x8
Revises: r2s3t4u5v6w7
Create Date: 2026-07-24 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 's3t4u5v6w7x8'
down_revision: Union[str, None] = 'r2s3t4u5v6w7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # App Settings screen — "App Language" picker (English/Hindi/Spanish
    # in the Flutter app). Previously stored only in the local Hive
    # SettingsModel, so it never synced across devices/reinstalls — same
    # class of bug as studio_name before it. Named app_language (not
    # "language") to stay distinct from the existing `languages` column,
    # which is the studio's list of spoken languages shown on its public
    # profile, not the user's own UI language preference.
    op.add_column(
        'users',
        sa.Column('app_language', sa.String(length=30), nullable=False, server_default='English'),
    )
    # Drop the server default once existing rows are backfilled — new
    # inserts already supply the value via the SQLAlchemy model default.
    op.alter_column('users', 'app_language', server_default=None)


def downgrade() -> None:
    op.drop_column('users', 'app_language')
