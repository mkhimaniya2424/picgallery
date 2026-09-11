"""support_collection_shares

Revision ID: 5dae0dae3028
Revises: b4f53c9dd1ff
Create Date: 2026-09-12 01:10:23.790807

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '5dae0dae3028'
down_revision: Union[str, None] = 'a8f8f59a1a64'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # share_links
    op.alter_column('share_links', 'album_id', existing_type=sa.UUID(), nullable=True)
    op.add_column('share_links', sa.Column('collection_id', sa.UUID(), nullable=True))
    op.create_foreign_key(
        'fk_share_links_collection_id',
        'share_links', 'gallery_collections',
        ['collection_id'], ['id'], ondelete='CASCADE'
    )
    op.create_index('ix_share_links_collection_id', 'share_links', ['collection_id'])
    
    op.create_check_constraint(
        'ck_share_links_target',
        'share_links',
        '(album_id IS NOT NULL AND collection_id IS NULL) OR (album_id IS NULL AND collection_id IS NOT NULL)'
    )

    # download_events
    op.add_column('download_events', sa.Column('collection_id', sa.UUID(), nullable=True))
    op.create_foreign_key(
        'fk_download_events_collection_id',
        'download_events', 'gallery_collections',
        ['collection_id'], ['id'], ondelete='SET NULL'
    )
    op.create_index('ix_download_events_collection_id', 'download_events', ['collection_id'])


def downgrade() -> None:
    # download_events
    op.drop_index('ix_download_events_collection_id', table_name='download_events')
    op.drop_constraint('fk_download_events_collection_id', 'download_events', type_='foreignkey')
    op.drop_column('download_events', 'collection_id')

    # share_links
    op.drop_constraint('ck_share_links_target', 'share_links', type_='check')
    op.drop_index('ix_share_links_collection_id', table_name='share_links')
    op.drop_constraint('fk_share_links_collection_id', 'share_links', type_='foreignkey')
    op.drop_column('share_links', 'collection_id')
    op.alter_column('share_links', 'album_id', existing_type=sa.UUID(), nullable=False)
