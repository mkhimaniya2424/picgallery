"""add pre_edit backup fields to media

Revision ID: w7x8y9z0a1b2
Revises: v6w7x8y9z0a1
Create Date: 2026-07-28 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'w7x8y9z0a1b2'
down_revision: Union[str, None] = 'v6w7x8y9z0a1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Photo editor "Overwrite Original" / "Revert to Original" (Task 21).
    # These hold the storage-relative keys of the file/thumbnail as they
    # were the *first* time a media item got destructively overwritten —
    # null means "never overwritten, nothing to revert". Nullable with
    # no default: existing rows simply have nothing to revert, which is
    # exactly the correct starting state.
    op.add_column('media', sa.Column('pre_edit_file_path', sa.String(length=500), nullable=True))
    op.add_column('media', sa.Column('pre_edit_thumbnail_path', sa.String(length=500), nullable=True))


def downgrade() -> None:
    op.drop_column('media', 'pre_edit_thumbnail_path')
    op.drop_column('media', 'pre_edit_file_path')
