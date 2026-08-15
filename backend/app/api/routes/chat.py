import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.chat import ChatMessage, ChatThread
from app.models.connection import ConnectionStatus, StudioClientConnection
from app.models.user import User, UserRole
from app.schemas.chat import ChatMessageCreate, ChatMessageRead, ChatMessagesList, ChatThreadRead

router = APIRouter(prefix="/chat", tags=["chat"])


def _get_connection_or_404(
    db: Session, connection_id: uuid.UUID, current_user: User
) -> StudioClientConnection:
    """Verifies the connection exists, is in `accepted` state, and the
    current user is one of the two parties. Raises 404/403 otherwise.
    """
    conn = db.get(StudioClientConnection, connection_id)
    if conn is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Connection not found"
        )
    if conn.status != ConnectionStatus.accepted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Connection is not active",
        )
    if current_user.id not in (conn.studio_id, conn.client_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not part of this connection",
        )
    return conn


def _get_thread_or_404(
    db: Session, thread_id: uuid.UUID, current_user: User
) -> tuple[ChatThread, StudioClientConnection]:
    """Gets a thread and verifies the current user is part of the
    underlying connection. Returns (thread, connection).
    """
    thread = db.get(ChatThread, thread_id)
    if thread is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Thread not found"
        )
    conn = db.get(StudioClientConnection, thread.connection_id)
    if conn is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Connection not found"
        )
    if current_user.id not in (conn.studio_id, conn.client_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not part of this thread",
        )
    return thread, conn


def _get_or_create_thread(db: Session, connection_id: uuid.UUID) -> ChatThread:
    """Returns the existing thread for a connection, or creates one."""
    thread = db.execute(
        select(ChatThread).where(ChatThread.connection_id == connection_id)
    ).scalar_one_or_none()
    if thread is None:
        thread = ChatThread(connection_id=connection_id)
        db.add(thread)
        db.flush()
    return thread


def _resolve_other_party(
    db: Session, connection: StudioClientConnection, current_user: User
) -> User:
    """Returns the *other* user in a connection."""
    other_id = (
        connection.client_id
        if current_user.id == connection.studio_id
        else connection.studio_id
    )
    other = db.get(User, other_id)
    if other is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Other party not found"
        )
    return other


# ---------------------------------------------------------------------------
# GET /chat/threads
# ---------------------------------------------------------------------------


@router.get("/threads", response_model=list[ChatThreadRead])
def list_threads(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[ChatThreadRead]:
    """Lists all chat threads the current user participates in. Threads
    are ordered by `last_message_at` (most recent first), then by
    `created_at` (newest first) for empty threads.

    For each thread, the other party's display name and avatar are
    resolved so the client can render the thread list without needing to
    look up the connection separately.
    """
    if current_user.role == UserRole.photographer:
        conn_column = StudioClientConnection.studio_id
    else:
        conn_column = StudioClientConnection.client_id

    # Find all accepted connections for this user, join with threads
    stmt = (
        select(ChatThread)
        .join(
            StudioClientConnection,
            ChatThread.connection_id == StudioClientConnection.id,
        )
        .where(
            conn_column == current_user.id,
            StudioClientConnection.status == ConnectionStatus.accepted,
        )
        .order_by(
            ChatThread.last_message_at.desc().nullslast(),
            ChatThread.created_at.desc(),
        )
    )
    threads = db.execute(stmt).scalars().all()

    result = []
    for thread in threads:
        conn = db.get(StudioClientConnection, thread.connection_id)
        if conn is None:
            continue
        other = _resolve_other_party(db, conn, current_user)
        result.append(
            ChatThreadRead.from_model(
                thread,
                other_party_name=other.full_name if other else "Unknown",
                other_party_avatar=other.avatar_url if other else None,
            )
        )
    return result


# ---------------------------------------------------------------------------
# GET /chat/threads/{id}/messages
# ---------------------------------------------------------------------------


@router.get("/threads/{thread_id}/messages", response_model=ChatMessagesList)
def list_messages(
    thread_id: uuid.UUID,
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatMessagesList:
    """Returns paginated messages for a thread, newest first (so the
    client can prepend older pages above the current view). The `total`
    field lets the client know when it's hit the end.

    Also marks all messages from the *other* party as read when the
    recipient fetches them.
    """
    thread, _ = _get_thread_or_404(db, thread_id, current_user)

    # Mark unread messages from the other side as read
    subq = (
        select(ChatMessage.id)
        .where(
            ChatMessage.thread_id == thread_id,
            ChatMessage.sender_id != current_user.id,
            ChatMessage.is_read.is_(False),
        )
        .subquery()
    )
    db.execute(
        ChatMessage.__table__.update()
        .where(ChatMessage.id.in_(select(subq.c.id)))
        .values(is_read=True)
    )

    # Count total
    total = (
        db.execute(
            select(func.count())
            .select_from(ChatMessage)
            .where(ChatMessage.thread_id == thread_id)
        ).scalar()
        or 0
    )

    # Fetch paginated (newest first for offset pagination)
    stmt = (
        select(ChatMessage)
        .where(ChatMessage.thread_id == thread_id)
        .order_by(ChatMessage.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    messages = db.execute(stmt).scalars().all()

    # Resolve sender roles
    items = []
    for msg in messages:
        sender = db.get(User, msg.sender_id)
        sender_role = sender.role.value if sender else ""
        items.append(ChatMessageRead.from_model(msg, sender_role=sender_role))

    # Return in chronological order (oldest first) for the UI
    items.reverse()
    db.commit()

    return ChatMessagesList(items=items, total=total, limit=limit, offset=offset)


# ---------------------------------------------------------------------------
# POST /chat/threads/{id}/messages
# ---------------------------------------------------------------------------


@router.post(
    "/threads/{thread_id}/messages",
    response_model=ChatMessageRead,
    status_code=status.HTTP_201_CREATED,
)
def send_message(
    thread_id: uuid.UUID,
    payload: ChatMessageCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatMessageRead:
    """Sends a message in an existing thread.

    Also updates the thread's `last_message_at` and
    `last_message_preview` atomically.
    """
    thread, _ = _get_thread_or_404(db, thread_id, current_user)

    message = ChatMessage(
        thread_id=thread.id,
        sender_id=current_user.id,
        text=payload.text,
    )
    db.add(message)
    db.flush()

    # Update thread metadata
    now = datetime.now(timezone.utc)
    thread.last_message_at = now
    thread.last_message_preview = payload.text[:200]

    db.commit()
    db.refresh(message)

    return ChatMessageRead.from_model(
        message,
        sender_role=current_user.role.value,
    )


# ---------------------------------------------------------------------------
# POST /chat/by-connection/{connection_id}/messages — convenience endpoint
# that finds (or creates) the thread for a connection, then calls send.
# ---------------------------------------------------------------------------


@router.post(
    "/by-connection/{connection_id}/messages",
    response_model=ChatMessageRead,
    status_code=status.HTTP_201_CREATED,
)
def send_message_by_connection(
    connection_id: uuid.UUID,
    payload: ChatMessageCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ChatMessageRead:
    """Convenience endpoint: sends a message on the thread belonging to
    a given (accepted) connection. If no thread exists yet, one is
    created automatically.

    This lets the client send a message without first resolving the
    thread id — it only needs the connection id, which it already has
    from its connections list.
    """
    conn = _get_connection_or_404(db, connection_id, current_user)
    thread = _get_or_create_thread(db, connection_id)

    message = ChatMessage(
        thread_id=thread.id,
        sender_id=current_user.id,
        text=payload.text,
    )
    db.add(message)
    db.flush()

    now = datetime.now(timezone.utc)
    thread.last_message_at = now
    thread.last_message_preview = payload.text[:200]

    db.commit()
    db.refresh(message)

    return ChatMessageRead.from_model(
        message,
        sender_role=current_user.role.value,
    )

