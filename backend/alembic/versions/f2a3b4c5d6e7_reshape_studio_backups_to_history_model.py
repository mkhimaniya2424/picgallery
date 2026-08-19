"""reshape studio_backups: overwrite-model -> history-model

d5e6f7a8b9c0 (the migration actually applied to this DB) created
studio_backups as one-row-per-owner (UniqueConstraint on owner_id,
each backup overwrites the last) with an owner_id index.

The live StudioBackup SQLAlchemy model (app/models/studio_backup.py)
expects the OTHER shape: one row per backup call, history retained,
looked up via `ORDER BY created_at DESC LIMIT 1` for "latest". That
shape needs no unique constraint on owner_id, doesn't need
updated_at (rows are never updated, only inserted), and needs an
index on created_at instead of (or in addition to) owner_id.

This migration reconciles the two: drops the owner_id uniqueness so
multiple backups per studio can exist, drops the now-unused
updated_at column, and adds the created_at index the model's
"most recent" query relies on. No data is deleted — existing rows
are kept as-is under the new (looser) constraints.

Revision ID: f2a3b4c5d6e7
Revises: d5e6f7a8b9c0
Create Date: 2026-08-19 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f2a3b4c5d6e7'
down_revision: Union[str, None] = 'd5e6f7a8b9c0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_constraint('uq_studio_backups_owner_id', 'studio_backups', type_='unique')
    op.drop_column('studio_backups', 'updated_at')
    op.create_index('ix_studio_backups_created_at', 'studio_backups', ['created_at'])


def downgrade() -> None:
    op.drop_index('ix_studio_backups_created_at', table_name='studio_backups')
    op.add_column(
        'studio_backups',
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_unique_constraint('uq_studio_backups_owner_id', 'studio_backups', ['owner_id'])