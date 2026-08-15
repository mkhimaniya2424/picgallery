"""create album_client_shares table

Revision ID: z0a1b2c3d4e5
Revises: y9z0a1b2c3d4
Create Date: 2026-07-29 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "z0a1b2c3d4e5"
down_revision: Union[str, None] = "y9z0a1b2c3d4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "album_client_shares",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "album_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("albums.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "client_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "studio_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "shared_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column(
            "revoked_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    op.create_index(
        "ix_album_client_shares_album_id",
        "album_client_shares",
        ["album_id"],
    )

    op.create_index(
        "ix_album_client_shares_client_id",
        "album_client_shares",
        ["client_id"],
    )

    op.create_index(
        "ix_album_client_shares_studio_id",
        "album_client_shares",
        ["studio_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_album_client_shares_studio_id", table_name="album_client_shares")
    op.drop_index("ix_album_client_shares_client_id", table_name="album_client_shares")
    op.drop_index("ix_album_client_shares_album_id", table_name="album_client_shares")
    op.drop_table("album_client_shares")