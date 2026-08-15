from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.user import User, UserRole

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_access_token(token)
        user_id: str | None = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.get(User, user_id)
    if user is None or user.is_deleted:
        # There's no separate token/session store in this app (access
        # tokens are stateless JWTs), so checking is_deleted here is
        # what actually "revokes" a deleted account's outstanding
        # tokens — the very next request with the old token is rejected
        # instead of quietly succeeding until it expires.
        raise credentials_exception
    return user


def get_current_studio_user(current_user: User = Depends(get_current_user)) -> User:
    """Gallery routes (folders/albums/media) are studio-only — a studio's
    gallery is their own private working library, not something a
    client account creates or edits. Client-facing read access to a
    studio's gallery (via share links) is handled by separate public
    routes, not this dependency.
    """
    if current_user.role != UserRole.photographer:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only studio accounts can manage a gallery.",
        )
    return current_user


def get_current_client_user(current_user: User = Depends(get_current_user)) -> User:
    """Studio-favoriting routes (Task 3) are client-only — favoriting a
    studio is something a client does, not something a studio does to
    itself. Mirrors `get_current_studio_user` above.
    """
    if current_user.role != UserRole.client:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only client accounts can favorite studios.",
        )
    return current_user
