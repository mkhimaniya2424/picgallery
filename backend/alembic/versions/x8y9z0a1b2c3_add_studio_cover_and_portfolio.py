"""add studio cover photo and portfolio images

Revision ID: x8y9z0a1b2c3
Revises: w7x8y9z0a1b2
Create Date: 2026-07-29 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'x8y9z0a1b2c3'
down_revision: Union[str, None] = 'w7x8y9z0a1b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Studio cover photo — wide banner shown at the top of a studio's
    # public profile, same convention as the existing avatar_url column.
    op.add_column('users', sa.Column('cover_image_url', sa.String(length=500), nullable=True))

    # Showcase Portfolio grid.
    op.create_table(
        'studio_portfolio_images',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('owner_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('relative_path', sa.String(length=500), nullable=False),
        sa.Column('display_order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_studio_portfolio_images_owner_id', 'studio_portfolio_images', ['owner_id'])


def downgrade() -> None:
    op.drop_index('ix_studio_portfolio_images_owner_id', table_name='studio_portfolio_images')
    op.drop_table('studio_portfolio_images')
    op.drop_column('users', 'cover_image_url')