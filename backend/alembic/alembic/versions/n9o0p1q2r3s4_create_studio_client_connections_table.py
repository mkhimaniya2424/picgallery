"""create studio_client_connections table

Revision ID: n9o0p1q2r3s4
Revises: m8n9o0p1q2r3
Create Date: 2026-07-23 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "n9o0p1q2r3s4"
down_revision: Union[str, None] = "m8n9o0p1q2r3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


connection_status = postgresql.ENUM(
    "pending",
    "accepted",
    "declined",
    name="connection_status",
    create_type=False,
)

connection_initiator = postgresql.ENUM(
    "studio",
    "client",
    name="connection_initiator",
    create_type=False,
)


def upgrade() -> None:
    # Create ENUMs only if they don't already exist
    connection_status.create(op.get_bind(), checkfirst=True)
    connection_initiator.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "studio_client_connections",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "studio_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "client_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "status",
            connection_status,
            nullable=False,
            server_default="pending",
        ),
        sa.Column(
            "initiated_by",
            connection_initiator,
            nullable=False,
        ),
        sa.Column(
            "requested_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column(
            "responded_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "studio_id",
            "client_id",
            name="uq_studio_client_connections_studio_client",
        ),
    )

    op.create_index(
        "ix_studio_client_connections_studio_id",
        "studio_client_connections",
        ["studio_id"],
    )

    op.create_index(
        "ix_studio_client_connections_client_id",
        "studio_client_connections",
        ["client_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_studio_client_connections_client_id",
        table_name="studio_client_connections",
    )

    op.drop_index(
        "ix_studio_client_connections_studio_id",
        table_name="studio_client_connections",
    )

    op.drop_table("studio_client_connections")

    connection_initiator.drop(op.get_bind(), checkfirst=True)
    connection_status.drop(op.get_bind(), checkfirst=True)