"""create share_links table

Revision ID: h4i5j6k7l8m9
Revises: g1h2i3j4k5l6
Create Date: 2026-07-16 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'h4i5j6k7l8m9'
down_revision: Union[str, None] = 'g1h2i3j4k5l6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Share Links (Task 20) — a public, revocable link exposing exactly
    # one Album for client viewing without an account.
    op.create_table(
        'share_links',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('owner_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('album_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('albums.id', ondelete='CASCADE'), nullable=False),
        sa.Column('token', sa.String(length=64), nullable=False),
        sa.Column('password_hash', sa.String(length=255), nullable=True),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('allow_download', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('show_watermark', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('is_revoked', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('views_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('downloads_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('last_viewed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('last_downloaded_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_share_links_owner_id', 'share_links', ['owner_id'])
    op.create_index('ix_share_links_album_id', 'share_links', ['album_id'])
    op.create_index('ix_share_links_token', 'share_links', ['token'], unique=True)


def downgrade() -> None:
    op.drop_index('ix_share_links_token', table_name='share_links')
    op.drop_index('ix_share_links_album_id', table_name='share_links')
    op.drop_index('ix_share_links_owner_id', table_name='share_links')
    op.drop_table('share_links')
