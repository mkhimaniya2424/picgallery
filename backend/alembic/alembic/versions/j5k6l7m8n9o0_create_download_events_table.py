"""create download_events table

Revision ID: j5k6l7m8n9o0
Revises: i9j0k1l2m3n4
Create Date: 2026-07-16 13:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'j5k6l7m8n9o0'
down_revision: Union[str, None] = 'i9j0k1l2m3n4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Download History (Task 22) — an immutable audit-log row per
    # download, from anywhere (in-app or a public Share Link).
    # download_source_enum = postgresql.ENUM('app', 'share_link', name='download_source', create_type=False)
    download_source_enum = postgresql.ENUM('app', 'share_link', name='download_source', create_type=False)
    download_source_enum.create(op.get_bind(), checkfirst=True)

    # Reuses the existing `media_type` enum type created for the
    # `media` table — created_type=False so this migration doesn't try
    # (and fail) to recreate it.
    media_type_enum = postgresql.ENUM('photo', 'video', name='media_type', create_type=False)

    op.create_table(
        'download_events',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('owner_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('media_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('media.id', ondelete='SET NULL'), nullable=True),
        sa.Column('album_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('albums.id', ondelete='SET NULL'), nullable=True),
        sa.Column('share_link_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('share_links.id', ondelete='SET NULL'), nullable=True),
        sa.Column('downloaded_by_user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('downloader_label', sa.String(length=150), nullable=True),
        sa.Column('file_name', sa.String(length=255), nullable=False),
        sa.Column('media_type', media_type_enum, nullable=False),
        sa.Column('size_bytes', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('source', download_source_enum, nullable=False),
        sa.Column('downloaded_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_download_events_owner_id', 'download_events', ['owner_id'])
    op.create_index('ix_download_events_media_id', 'download_events', ['media_id'])
    op.create_index('ix_download_events_album_id', 'download_events', ['album_id'])
    op.create_index('ix_download_events_share_link_id', 'download_events', ['share_link_id'])
    op.create_index('ix_download_events_downloaded_by_user_id', 'download_events', ['downloaded_by_user_id'])
    op.create_index('ix_download_events_downloaded_at', 'download_events', ['downloaded_at'])


def downgrade() -> None:
    op.drop_index('ix_download_events_downloaded_at', table_name='download_events')
    op.drop_index('ix_download_events_downloaded_by_user_id', table_name='download_events')
    op.drop_index('ix_download_events_share_link_id', table_name='download_events')
    op.drop_index('ix_download_events_album_id', table_name='download_events')
    op.drop_index('ix_download_events_media_id', table_name='download_events')
    op.drop_index('ix_download_events_owner_id', table_name='download_events')
    op.drop_table('download_events')

    postgresql.ENUM(name='download_source').drop(op.get_bind(), checkfirst=True)