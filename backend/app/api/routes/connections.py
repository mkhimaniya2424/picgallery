import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_studio_user, get_current_user
from app.core.activity_log import log_activity
from app.db.session import get_db
from app.models.activity_log import ActivityType
from app.models.connection import ConnectionInitiator, ConnectionStatus, StudioClientConnection
from app.models.email_invitation import EmailInvitation
from app.models.notification import Notification, NotificationType
from app.models.user import User, UserRole
from app.core.firebase_service import send_push_notification
from app.schemas.connection import (
    ClientLookupRead,
    ClientSummary,
    ConnectionInviteByEmailCreate,
    ConnectionInviteCreate,
    ConnectionInviteResult,
    ConnectionRead,
)
from app.schemas.studio import StudioSummary

router = APIRouter(prefix="/connections", tags=["connections"])


def _get_connection_between(db: Session, studio_id: uuid.UUID, client_id: uuid.UUID) -> StudioClientConnection | None:
    return db.execute(
        select(StudioClientConnection).where(
            StudioClientConnection.studio_id == studio_id,
            StudioClientConnection.client_id == client_id,
        )
    ).scalar_one_or_none()


def _get_connection_or_404(db: Session, connection_id: uuid.UUID) -> StudioClientConnection:
    connection = db.get(StudioClientConnection, connection_id)
    if connection is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Connection not found")
    return connection


def _require_side(connection: StudioClientConnection, current_user: User) -> bool:
    """True if `current_user` is the studio side of `connection`, False if
    the client side. Raises 403 if they're neither (someone else's
    connection).
    """
    if current_user.role == UserRole.photographer and current_user.id == connection.studio_id:
        return True
    if current_user.role == UserRole.client and current_user.id == connection.client_id:
        return False
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="This connection doesn't belong to you.")


def _require_recipient(connection: StudioClientConnection, current_user: User) -> None:
    """Only the invited side may accept/decline — not whoever sent the
    invite in the first place.
    """
    is_studio_side = _require_side(connection, current_user)
    initiator_is_viewer = (
        is_studio_side and connection.initiated_by == ConnectionInitiator.studio
    ) or (not is_studio_side and connection.initiated_by == ConnectionInitiator.client)
    if initiator_is_viewer:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="You can't respond to your own invitation."
        )


def _serialize(connection: StudioClientConnection, viewer: User, db: Session) -> ConnectionRead:
    """Only the *other* party's profile is nested in the response — see
    `ConnectionRead` docstring.
    """
    if viewer.role == UserRole.photographer:
        other = db.get(User, connection.client_id)
        client_summary = ClientSummary.model_validate(other) if other is not None else None
        studio_summary = None
    else:
        other = db.get(User, connection.studio_id)
        studio_summary = StudioSummary.model_validate(other) if other is not None else None
        client_summary = None

    return ConnectionRead(
        id=connection.id,
        status=connection.status,
        initiated_by=connection.initiated_by,
        requested_at=connection.requested_at,
        responded_at=connection.responded_at,
        studio=studio_summary,
        client=client_summary,
    )


@router.get("/lookup-client", response_model=ClientLookupRead)
def lookup_client_by_email(
    email: str = Query(min_length=1),
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> ClientLookupRead:
    """Studio-only: resolves an email address (typed into the Invite New
    Client form) to an existing client account's id, so the form can
    then call `POST /connections/invite` with a real `client_id`.

    There is no "create a client" endpoint — client accounts only ever
    come from registration — so a 404 here means the studio should ask
    the client to sign up first rather than the form silently failing.
    `(email, role)` is unique (see `User.__table_args__`), so this
    matches at most one row.
    """
    client = db.execute(
        select(User).where(
            func.lower(User.email) == email.strip().lower(),
            User.role == UserRole.client,
            User.is_deleted.is_(False),
        )
    ).scalar_one_or_none()
    if client is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No PicGallery client account found for that email.",
        )
    return ClientLookupRead.model_validate(client)


def _invite_existing_client(
    db: Session,
    current_user: User,
    client: User,
) -> StudioClientConnection:
    """Shared core of inviting a client who already has an account —
    used by both `POST /connections/invite` (id-based, kept for
    backwards compatibility) and `POST /connections/invite-by-email`
    (email-based) once the latter has resolved the email to a real
    client row. Re-inviting a client who previously declined resets
    the existing row back to `pending` rather than creating a
    duplicate (mirrors the unique constraint on `(studio_id, client_id)`).
    """
    connection = _get_connection_between(db, current_user.id, client.id)
    if connection is not None:
        if connection.status == ConnectionStatus.accepted:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="You're already connected to this client."
            )
        if connection.status == ConnectionStatus.pending:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="An invitation to this client is already pending.",
            )
        connection.status = ConnectionStatus.pending
        connection.initiated_by = ConnectionInitiator.studio
        connection.requested_at = datetime.now(timezone.utc)
        connection.responded_at = None
    else:
        connection = StudioClientConnection(
            studio_id=current_user.id,
            client_id=client.id,
            status=ConnectionStatus.pending,
            initiated_by=ConnectionInitiator.studio,
        )
        db.add(connection)

    studio_name = current_user.studio_name or current_user.full_name

    # Flush (not commit) so an auto-generated `connection.id` is available
    # to embed in the Notification's `data` payload below, while still
    # landing both rows in the same transaction/commit.
    db.flush()

    db.add(
        Notification(
            user_id=client.id,
            type=NotificationType.connection,
            title="New connection invitation",
            subtitle=f"{studio_name} wants to connect with you.",
            data={"connection_id": str(connection.id)},
        )
    )

    db.commit()
    db.refresh(connection)

    # Push notification to client's device — gated on the client's
    # Notification Settings "Push Notifications" toggle
    # (`push_notifications_enabled`), not just whether a token exists.
    if client.fcm_token and client.push_notifications_enabled:
        send_push_notification(
            token=client.fcm_token,
            title="New Connection Invitation",
            body=f"{studio_name} wants to connect with you.",
            data={"type": "connection", "connection_id": str(connection.id)},
        )

    return connection


@router.post("/invite", response_model=ConnectionRead, status_code=status.HTTP_201_CREATED)
def invite_client(
    payload: ConnectionInviteCreate,
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> ConnectionRead:
    """Studio-only: invite a client (who already has an account) to
    connect, by id. Kept for backwards compatibility with older app
    builds; `POST /connections/invite-by-email` is the one the current
    "Invite New Client" form uses, since it also handles emails with no
    account yet.
    """
    client = db.get(User, payload.client_id)
    if client is None or client.role != UserRole.client or client.is_deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found")

    connection = _invite_existing_client(db, current_user, client)
    return _serialize(connection, current_user, db)


@router.post("/invite-by-email", response_model=ConnectionInviteResult, status_code=status.HTTP_201_CREATED)
def invite_client_by_email(
    payload: ConnectionInviteByEmailCreate,
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> ConnectionInviteResult:
    """Studio-only: invite a client by email, whether or not they have a
    PicGallery client account yet.

    - If the email matches an existing client account, behaves exactly
      like `POST /connections/invite` (id-based) and returns
      `status="connected"` with the resulting connection.
    - Otherwise, records an `EmailInvitation` (upserting — a repeat
      invite to the same email just bumps `created_at` and resends the
      invite rather than erroring). `auth.register` checks for matching
      `EmailInvitation` rows and turns them into a real pending
      connection the moment that email registers as a client — the client
      will receive a push notification at that point.
    """
    email = payload.email.strip().lower()

    client = db.execute(
        select(User).where(
            func.lower(User.email) == email,
            User.role == UserRole.client,
            User.is_deleted.is_(False),
        )
    ).scalar_one_or_none()

    if client is not None:
        connection = _invite_existing_client(db, current_user, client)
        return ConnectionInviteResult(
            status="connected",
            connection=_serialize(connection, current_user, db),
        )

    existing_invite = db.execute(
        select(EmailInvitation).where(
            EmailInvitation.studio_id == current_user.id,
            EmailInvitation.email == email,
        )
    ).scalar_one_or_none()

    if existing_invite is not None:
        existing_invite.created_at = datetime.now(timezone.utc)
        existing_invite.consumed_at = None
    else:
        db.add(EmailInvitation(studio_id=current_user.id, email=email))

    db.commit()

    return ConnectionInviteResult(status="invited_pending_signup", email=email)


@router.get("", response_model=list[ConnectionRead])
def list_connections(
    status_filter: ConnectionStatus | None = Query(default=None, alias="status"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[ConnectionRead]:
    """Available to both roles — a studio sees its invited/connected
    clients, a client sees the studios that invited it (or that it's
    connected to). Most-recently-requested first.
    """
    column = (
        StudioClientConnection.studio_id
        if current_user.role == UserRole.photographer
        else StudioClientConnection.client_id
    )

    stmt = select(StudioClientConnection).where(column == current_user.id)
    if status_filter is not None:
        stmt = stmt.where(StudioClientConnection.status == status_filter)
    stmt = stmt.order_by(StudioClientConnection.requested_at.desc())

    connections = db.execute(stmt).scalars().all()
    return [_serialize(connection, current_user, db) for connection in connections]


@router.post("/{connection_id}/accept", response_model=ConnectionRead)
def accept_connection(
    connection_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ConnectionRead:
    connection = _get_connection_or_404(db, connection_id)
    _require_recipient(connection, current_user)
    if connection.status != ConnectionStatus.pending:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="This invitation has already been responded to."
        )

    connection.status = ConnectionStatus.accepted
    connection.responded_at = datetime.now(timezone.utc)

    client = db.get(User, connection.client_id)
    log_activity(
        db,
        studio_id=connection.studio_id,
        type=ActivityType.client,
        title="New client connected",
        subtitle=client.full_name if client else "",
    )

    # Notify whoever's NOT the recipient here — i.e. whichever side sent
    # the original request/invite, since `_require_recipient` above
    # already guarantees `current_user` (who's accepting) is the other
    # side. Direction depends on `initiated_by`: a client-initiated
    # request means the studio just accepted, so the client hears back;
    # a studio-initiated invite means the client just accepted, so the
    # studio hears back.
    studio = db.get(User, connection.studio_id)
    studio_name = (studio.studio_name or studio.full_name) if studio else ""
    if connection.initiated_by == ConnectionInitiator.client:
        # Studio accepted the client's request → notify the CLIENT
        notif = Notification(
            user_id=connection.client_id,
            type=NotificationType.connection,
            title="Connected!",
            subtitle=f"{studio_name} accepted your request.",
            data={"connection_id": str(connection.id)},
        )
        db.add(notif)
        db.commit()
        db.refresh(connection)
        # Send live push to client's device — gated on the client's
        # push_notifications_enabled toggle.
        if client and client.fcm_token and client.push_notifications_enabled:
            send_push_notification(
                token=client.fcm_token,
                title="Connection Accepted! 🎉",
                body=f"{studio_name} accepted your connection request.",
                data={"type": "connection", "connection_id": str(connection.id)},
            )
    else:
        # Client accepted the studio's invite → notify the STUDIO
        notif = Notification(
            user_id=connection.studio_id,
            type=NotificationType.connection,
            title="Connected!",
            subtitle=f"{client.full_name if client else 'A client'} accepted your invitation.",
            data={"connection_id": str(connection.id)},
        )
        db.add(notif)
        db.commit()
        db.refresh(connection)
        # Send live push to studio's device — gated on the studio's
        # push_notifications_enabled toggle.
        if studio and studio.fcm_token and studio.push_notifications_enabled:
            send_push_notification(
                token=studio.fcm_token,
                title="New Client Connected! 🎉",
                body=f"{client.full_name if client else 'A client'} accepted your invitation.",
                data={"type": "connection", "connection_id": str(connection.id)},
            )

    return _serialize(connection, current_user, db)


@router.post("/{connection_id}/decline", response_model=ConnectionRead)
def decline_connection(
    connection_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ConnectionRead:
    connection = _get_connection_or_404(db, connection_id)
    _require_recipient(connection, current_user)
    if connection.status != ConnectionStatus.pending:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="This invitation has already been responded to."
        )

    connection.status = ConnectionStatus.declined
    connection.responded_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(connection)
    return _serialize(connection, current_user, db)


@router.delete("/{connection_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_connection(
    connection_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Available to both roles.

    - **Accepted** connections: either side may remove (disconnect).
    - **Pending** connections: only the side that *initiated* the invite/request
      may withdraw it — studios can cancel a sent invitation, clients can
      withdraw a connection request they sent.
    """
    connection = _get_connection_or_404(db, connection_id)

    # Confirm caller is a party to this connection.
    if current_user.id not in [connection.studio_id, connection.client_id]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to remove this connection.",
        )

    if connection.status == ConnectionStatus.accepted:
        # Either side can disconnect an accepted connection.
        pass
    elif connection.status == ConnectionStatus.pending:
        # Only the initiator may withdraw their own pending invite/request.
        initiator_id = (
            connection.studio_id
            if connection.initiated_by == ConnectionInitiator.studio
            else connection.client_id
        )
        if current_user.id != initiator_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only the sender can withdraw a pending invitation.",
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This connection cannot be removed.",
        )

    db.delete(connection)
    db.commit()