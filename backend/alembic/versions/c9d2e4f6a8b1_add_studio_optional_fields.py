"""add studio optional fields (task 3)

Revision ID: c9d2e4f6a8b1
Revises: b3c5d7e9f1a2
Create Date: 2026-07-14 11:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c9d2e4f6a8b1'
down_revision: Union[str, None] = 'b3c5d7e9f1a2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Studio profile fields — photographer ("Studio") role only, always
    # nullable/unset for client accounts. `service_areas`, `languages`,
    # and `availability_days` are list-type in the API but stored here
    # as comma-separated strings, same convention as `specializations`.
    op.add_column('users', sa.Column('year_established', sa.Integer(), nullable=True))
    op.add_column('users', sa.Column('team_size', sa.Integer(), nullable=True))
    op.add_column('users', sa.Column('service_areas', sa.String(length=500), nullable=True))
    op.add_column('users', sa.Column('studio_type', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('experience_years', sa.Integer(), nullable=True))
    op.add_column('users', sa.Column('languages', sa.String(length=255), nullable=True))
    op.add_column('users', sa.Column('equipment_highlights', sa.Text(), nullable=True))
    op.add_column('users', sa.Column('pricing_min', sa.Numeric(precision=10, scale=2), nullable=True))
    op.add_column('users', sa.Column('pricing_max', sa.Numeric(precision=10, scale=2), nullable=True))
    op.add_column('users', sa.Column('package_details', sa.Text(), nullable=True))
    op.add_column('users', sa.Column('availability_days', sa.String(length=255), nullable=True))
    op.add_column('users', sa.Column('instagram_url', sa.String(length=500), nullable=True))
    op.add_column('users', sa.Column('facebook_url', sa.String(length=500), nullable=True))
    op.add_column('users', sa.Column('youtube_url', sa.String(length=500), nullable=True))
    op.add_column('users', sa.Column('pinterest_url', sa.String(length=500), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'pinterest_url')
    op.drop_column('users', 'youtube_url')
    op.drop_column('users', 'facebook_url')
    op.drop_column('users', 'instagram_url')
    op.drop_column('users', 'availability_days')
    op.drop_column('users', 'package_details')
    op.drop_column('users', 'pricing_max')
    op.drop_column('users', 'pricing_min')
    op.drop_column('users', 'equipment_highlights')
    op.drop_column('users', 'languages')
    op.drop_column('users', 'experience_years')
    op.drop_column('users', 'studio_type')
    op.drop_column('users', 'service_areas')
    op.drop_column('users', 'team_size')
    op.drop_column('users', 'year_established')
