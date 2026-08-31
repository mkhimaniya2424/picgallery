"""create face_embeddings table (Face Search)

Revision ID: r2s3t4u5v6w7
Revises: q1r2s3t4u5v6
Create Date: 2026-07-24 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
import pgvector.sqlalchemy

# revision identifiers, used by Alembic.
revision: str = "r2s3t4u5v6w7"
down_revision: Union[str, None] = "q1r2s3t4u5v6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Supabase projects have the pgvector extension available but not
    # always enabled by default — this is a no-op if it's already on.
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        "face_embeddings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("media_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("media.id", ondelete="CASCADE"), nullable=False),
        sa.Column("owner_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("embedding", pgvector.sqlalchemy.Vector(512), nullable=False),
        sa.Column("box", postgresql.JSONB, nullable=False),
        sa.Column("detection_confidence", sa.Float(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_face_embeddings_media_id", "face_embeddings", ["media_id"])
    op.create_index("ix_face_embeddings_owner_id", "face_embeddings", ["owner_id"])

    # HNSW index on cosine distance — lets `POST /faces/search` and the
    # public share-link equivalent scale past a brute-force scan once a
    # studio's library grows large. Requires pgvector >= 0.5.0 (Supabase
    # ships a current version); if your Postgres has an older pgvector,
    # swap this for an ivfflat index instead.
    op.execute(
        "CREATE INDEX ix_face_embeddings_embedding_cosine "
        "ON face_embeddings USING hnsw (embedding vector_cosine_ops)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_face_embeddings_embedding_cosine")
    op.drop_index("ix_face_embeddings_owner_id", table_name="face_embeddings")
    op.drop_index("ix_face_embeddings_media_id", table_name="face_embeddings")
    op.drop_table("face_embeddings")
