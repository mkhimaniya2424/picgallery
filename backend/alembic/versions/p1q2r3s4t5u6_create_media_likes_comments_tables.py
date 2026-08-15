"""create media_likes and media_comments tables

Revision ID: p1q2r3s4t5u6
Revises: o0p1q2r3s4t5
Create Date: 2026-07-25 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'p1q2r3s4t5u6'
down_revision: Union[str, None] = 'o0p1q2r3s4t5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- Media Likes ---
    op.create_table(
        'media_likes',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('media_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('media.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint('media_id', 'user_id', name='uq_media_likes_media_user'),
    )
    op.create_index('ix_media_likes_media_id', 'media_likes', ['media_id'])
    op.create_index('ix_media_likes_user_id', 'media_likes', ['user_id'])

    # --- Media Comments ---
    op.create_table(
        'media_comments',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('media_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('media.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('parent_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('media_comments.id', ondelete='CASCADE'), nullable=True),
        sa.Column('text', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index('ix_media_comments_media_id', 'media_comments', ['media_id'])
    op.create_index('ix_media_comments_user_id', 'media_comments', ['user_id'])
    op.create_index('ix_media_comments_parent_id', 'media_comments', ['parent_id'])


def downgrade() -> None:
    op.drop_index('ix_media_comments_parent_id', table_name='media_comments')
    op.drop_index('ix_media_comments_user_id', table_name='media_comments')
    op.drop_index('ix_media_comments_media_id', table_name='media_comments')
    op.drop_table('media_comments')

    op.drop_index('ix_media_likes_user_id', table_name='media_likes')
    op.drop_index('ix_media_likes_media_id', table_name='media_likes')
    op.drop_table('media_likes')

