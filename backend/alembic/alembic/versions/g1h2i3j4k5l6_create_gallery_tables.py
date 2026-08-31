"""create gallery tables (folders, albums, media)

Revision ID: g1h2i3j4k5l6
Revises: a1b2c3d4e5f6
Create Date: 2026-07-16 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'g1h2i3j4k5l6'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'folders',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('owner_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(length=150), nullable=False),
        sa.Column('parent_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('folders.id', ondelete='CASCADE'), nullable=True),
        sa.Column('gradient_argb', sa.String(length=255), nullable=True),
        sa.Column('is_hidden', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('is_favorite', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_folders_owner_id', 'folders', ['owner_id'])
    op.create_index('ix_folders_parent_id', 'folders', ['parent_id'])

    op.create_table(
        'albums',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('owner_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('folder_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('folders.id', ondelete='SET NULL'), nullable=True),
        sa.Column('name', sa.String(length=150), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('display_order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('is_favorite', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('gradient_argb', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_albums_owner_id', 'albums', ['owner_id'])
    op.create_index('ix_albums_folder_id', 'albums', ['folder_id'])

    # media_type_enum = postgresql.ENUM('photo', 'video', name='media_type')
    media_type_enum = postgresql.ENUM('photo', 'video', name='media_type', create_type=False)
    media_type_enum.create(op.get_bind(), checkfirst=True)

    op.create_table(
        'media',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('owner_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('album_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('albums.id', ondelete='SET NULL'), nullable=True),
        sa.Column('folder_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('folders.id', ondelete='SET NULL'), nullable=True),
        sa.Column('media_type', media_type_enum, nullable=False),
        sa.Column('file_name', sa.String(length=255), nullable=False),
        sa.Column('file_path', sa.String(length=500), nullable=False),
        sa.Column('thumbnail_path', sa.String(length=500), nullable=True),
        sa.Column('content_type', sa.String(length=100), nullable=False),
        sa.Column('size_bytes', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('width', sa.Integer(), nullable=True),
        sa.Column('height', sa.Integer(), nullable=True),
        sa.Column('duration_ms', sa.Integer(), nullable=True),
        sa.Column('is_favorite', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('edit_recipe', postgresql.JSONB(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_media_owner_id', 'media', ['owner_id'])
    op.create_index('ix_media_album_id', 'media', ['album_id'])
    op.create_index('ix_media_folder_id', 'media', ['folder_id'])


def downgrade() -> None:
    op.drop_index('ix_media_folder_id', table_name='media')
    op.drop_index('ix_media_album_id', table_name='media')
    op.drop_index('ix_media_owner_id', table_name='media')
    op.drop_table('media')
    postgresql.ENUM(name='media_type').drop(op.get_bind(), checkfirst=True)

    op.drop_index('ix_albums_folder_id', table_name='albums')
    op.drop_index('ix_albums_owner_id', table_name='albums')
    op.drop_table('albums')

    op.drop_index('ix_folders_parent_id', table_name='folders')
    op.drop_index('ix_folders_owner_id', table_name='folders')
    op.drop_table('folders')
