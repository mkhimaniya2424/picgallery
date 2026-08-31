"""create gallery collections tables

Revision ID: i9j0k1l2m3n4
Revises: h4i5j6k7l8m9
Create Date: 2026-07-16 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'i9j0k1l2m3n4'
down_revision: Union[str, None] = 'h4i5j6k7l8m9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Gallery Collections (Task 21) — an ordered grouping of Albums.
    op.create_table(
        'gallery_collections',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('owner_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(length=150), nullable=False),
        sa.Column('display_order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_gallery_collections_owner_id', 'gallery_collections', ['owner_id'])

    # Join table giving each (collection, album) membership an explicit
    # order via `position`, and a proper CASCADE on album_id so a
    # deleted album silently drops out of every collection it was in.
    op.create_table(
        'collection_items',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('collection_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('gallery_collections.id', ondelete='CASCADE'), nullable=False),
        sa.Column('album_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('albums.id', ondelete='CASCADE'), nullable=False),
        sa.Column('position', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_collection_items_collection_id', 'collection_items', ['collection_id'])
    op.create_index('ix_collection_items_album_id', 'collection_items', ['album_id'])
    op.create_unique_constraint(
        'uq_collection_items_collection_album', 'collection_items', ['collection_id', 'album_id']
    )


def downgrade() -> None:
    op.drop_constraint('uq_collection_items_collection_album', 'collection_items', type_='unique')
    op.drop_index('ix_collection_items_album_id', table_name='collection_items')
    op.drop_index('ix_collection_items_collection_id', table_name='collection_items')
    op.drop_table('collection_items')

    op.drop_index('ix_gallery_collections_owner_id', table_name='gallery_collections')
    op.drop_table('gallery_collections')
