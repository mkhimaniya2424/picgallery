"""create studio_favorites table

Revision ID: l7m8n9o0p1q2
Revises: k6l7m8n9o0p1
Create Date: 2026-07-23 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'l7m8n9o0p1q2'
down_revision: Union[str, None] = 'k6l7m8n9o0p1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Favorite Studios (Task 3) — a client's favorited studio accounts.
    op.create_table(
        'studio_favorites',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('client_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('studio_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint('client_id', 'studio_id', name='uq_studio_favorites_client_studio'),
    )
    op.create_index('ix_studio_favorites_client_id', 'studio_favorites', ['client_id'])
    op.create_index('ix_studio_favorites_studio_id', 'studio_favorites', ['studio_id'])


def downgrade() -> None:
    op.drop_index('ix_studio_favorites_studio_id', table_name='studio_favorites')
    op.drop_index('ix_studio_favorites_client_id', table_name='studio_favorites')
    op.drop_table('studio_favorites')
