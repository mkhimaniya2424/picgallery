"""Add privacy fields

Revision ID: c294bb6c5ebf
Revises: 0ed11a01d853
Create Date: 2026-08-25 15:56:46.370413

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c294bb6c5ebf'
down_revision: Union[str, None] = '0ed11a01d853'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('private_profile', sa.Boolean(), server_default='false', nullable=False))
    op.add_column('users', sa.Column('search_engine_indexing', sa.Boolean(), server_default='true', nullable=False))


def downgrade() -> None:
    op.drop_column('users', 'search_engine_indexing')
    op.drop_column('users', 'private_profile')
