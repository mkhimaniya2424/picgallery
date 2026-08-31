"""add client_id to share_links

Revision ID: h9i0j1k2l3m4
Revises: f4a6b8c0d2e4
Create Date: 2026-08-31 00:00:00.000000

The `ShareLink` model (app/models/gallery.py) has always declared a
`client_id` column, but the original `create_share_links_table`
migration (h4i5j6k7l8m9) never included it — every create/update on
`POST /share-links` and `PATCH /share-links/{id}` has been trying to
INSERT/UPDATE a column that doesn't exist in the database, which
Postgres rejects and which the app's global exception handler turns
into a generic 500 ("Something went wrong on our end.").
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'h9i0j1k2l3m4'
down_revision: Union[str, None] = 'f4a6b8c0d2e4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'share_links',
        sa.Column(
            'client_id',
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey('users.id', ondelete='SET NULL'),
            nullable=True,
        ),
    )
    op.create_index('ix_share_links_client_id', 'share_links', ['client_id'])


def downgrade() -> None:
    op.drop_index('ix_share_links_client_id', table_name='share_links')
    op.drop_column('share_links', 'client_id')
