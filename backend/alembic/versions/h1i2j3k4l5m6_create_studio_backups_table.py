"""create studio_backups table

Revision ID: h1i2j3k4l5m6
Revises: c3d4e5f6a7b8
Create Date: 2026-08-17 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'h1i2j3k4l5m6'
down_revision: Union[str, None] = 'c3d4e5f6a7b8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Backup & Restore (Task 6) — one row per settings-backup snapshot a
    # studio has created. No settings table exists server-side yet, so
    # `payload` just stores whatever JSON blob the app posts.
    op.create_table(
        'studio_backups',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('owner_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('payload', postgresql.JSONB(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_studio_backups_owner_id', 'studio_backups', ['owner_id'])
    op.create_index('ix_studio_backups_created_at', 'studio_backups', ['created_at'])


def downgrade() -> None:
    op.drop_index('ix_studio_backups_created_at', table_name='studio_backups')
    op.drop_index('ix_studio_backups_owner_id', table_name='studio_backups')
    op.drop_table('studio_backups')