"""add client optional fields (task 4)

Revision ID: d8e3f5a7b9c1
Revises: c9d2e4f6a8b1
Create Date: 2026-07-14 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd8e3f5a7b9c1'
down_revision: Union[str, None] = 'c9d2e4f6a8b1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Client optional profile fields — client role only, always
    # nullable/unset for photographer accounts. `preferred_photo_types`
    # is list-type in the API but stored here as a comma-separated
    # string, same convention as `specializations`/`service_areas`.
    op.add_column('users', sa.Column('profile_photo_url', sa.String(length=500), nullable=True))
    op.add_column('users', sa.Column('gender', sa.String(length=20), nullable=True))
    op.add_column('users', sa.Column('date_of_birth', sa.Date(), nullable=True))
    op.add_column('users', sa.Column('preferred_photo_types', sa.String(length=255), nullable=True))
    op.add_column('users', sa.Column('preferred_city', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('budget_min', sa.Numeric(precision=10, scale=2), nullable=True))
    op.add_column('users', sa.Column('budget_max', sa.Numeric(precision=10, scale=2), nullable=True))
    op.add_column('users', sa.Column('alternate_phone', sa.String(length=30), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'alternate_phone')
    op.drop_column('users', 'budget_max')
    op.drop_column('users', 'budget_min')
    op.drop_column('users', 'preferred_city')
    op.drop_column('users', 'preferred_photo_types')
    op.drop_column('users', 'date_of_birth')
    op.drop_column('users', 'gender')
    op.drop_column('users', 'profile_photo_url')
