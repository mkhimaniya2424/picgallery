"""create email_invitations table

Revision ID: y9z0a1b2c3d4
Revises: x8y9z0a1b2c3
Create Date: 2026-07-29 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "y9z0a1b2c3d4"
down_revision: Union[str, None] = "x8y9z0a1b2c3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "email_invitations",
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
            "email",
            sa.String(length=320),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column(
            "consumed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.UniqueConstraint(
            "studio_id",
            "email",
            name="uq_email_invitations_studio_email",
        ),
    )

    op.create_index(
        "ix_email_invitations_studio_id",
        "email_invitations",
        ["studio_id"],
    )

    op.create_index(
        "ix_email_invitations_email",
        "email_invitations",
        ["email"],
    )


def downgrade() -> None:
    op.drop_index("ix_email_invitations_email", table_name="email_invitations")
    op.drop_index("ix_email_invitations_studio_id", table_name="email_invitations")
    op.drop_table("email_invitations")
