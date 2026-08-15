"""Server-side verification of Sign in with Google / Sign in with Apple
ID tokens for POST /auth/social-login.

Both providers hand the client (Flutter app) a signed JWT after the
user authenticates on-device. The backend never trusts that token at
face value — it re-verifies the signature against the provider's own
public keys and checks the audience/issuer/expiry itself, so a forged
or replayed token from anywhere else can't be used to log in as
someone else. This is the same trust model FastAPI's own
`create_access_token`/`decode_access_token` use for our own JWTs, just
pointed at Google's/Apple's keys instead of our SECRET_KEY.
"""
from __future__ import annotations

import time
from dataclasses import dataclass

import requests
from fastapi import HTTPException, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from jose import jwt as jose_jwt
from jose.exceptions import JOSEError

from app.core.config import settings

APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"

# Apple's JWKS is small and rotates rarely — refetching on every login
# would be wasteful, so it's cached and only refreshed if a token's
# `kid` isn't found in the cached set (e.g. Apple rotated keys).
_apple_jwks_cache: dict | None = None


@dataclass(frozen=True)
class SocialIdentity:
    """The provider-verified identity extracted from an ID token —
    enough to find-or-create the local User row in the auth route."""

    provider_user_id: str
    email: str | None
    email_verified: bool
    full_name: str | None = None


def _fetch_apple_jwks() -> dict:
    response = requests.get(APPLE_KEYS_URL, timeout=10)
    response.raise_for_status()
    return response.json()


def _get_apple_jwk(kid: str) -> dict:
    global _apple_jwks_cache
    if _apple_jwks_cache is None:
        _apple_jwks_cache = _fetch_apple_jwks()

    for key in _apple_jwks_cache.get("keys", []):
        if key.get("kid") == kid:
            return key

    # Not found — maybe Apple rotated keys since we last cached them.
    # Refetch once before giving up.
    _apple_jwks_cache = _fetch_apple_jwks()
    for key in _apple_jwks_cache.get("keys", []):
        if key.get("kid") == kid:
            return key

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not verify Apple sign-in token (unknown signing key)",
    )


def verify_google_id_token(id_token_str: str) -> SocialIdentity:
    if not settings.GOOGLE_CLIENT_IDS:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Google sign-in is not configured on the server",
        )

    try:
        # audience=None here: we verify aud ourselves against the full
        # allow-list below, since a single app legitimately has several
        # valid client IDs (one per platform).
        claims = google_id_token.verify_oauth2_token(
            id_token_str, google_requests.Request(), audience=None
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Google sign-in token",
        ) from exc

    if claims.get("aud") not in settings.GOOGLE_CLIENT_IDS:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Google sign-in token was not issued for this app",
        )

    return SocialIdentity(
        provider_user_id=claims["sub"],
        email=claims.get("email"),
        email_verified=bool(claims.get("email_verified", False)),
        full_name=claims.get("name"),
    )


def verify_apple_identity_token(identity_token: str) -> SocialIdentity:
    if not settings.APPLE_CLIENT_IDS:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Apple sign-in is not configured on the server",
        )

    try:
        header = jose_jwt.get_unverified_header(identity_token)
        kid = header["kid"]
        jwk = _get_apple_jwk(kid)

        claims = jose_jwt.decode(
            identity_token,
            jwk,
            algorithms=[jwk.get("alg", "RS256")],
            audience=settings.APPLE_CLIENT_IDS,
            issuer=APPLE_ISSUER,
            options={"verify_at_hash": False},
        )
    except JOSEError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Apple sign-in token",
        ) from exc

    if claims.get("exp", 0) < time.time():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Apple sign-in token has expired",
        )

    # Apple only sends `email_verified` as a string ("true"/"false") on
    # some token versions rather than a bool — normalize either way.
    email_verified = claims.get("email_verified")
    if isinstance(email_verified, str):
        email_verified = email_verified.lower() == "true"

    return SocialIdentity(
        provider_user_id=claims["sub"],
        email=claims.get("email"),
        email_verified=bool(email_verified),
        # Apple's identity token itself never carries the user's name —
        # that's only handed to the client once, on the very first
        # authorization, as separate (unsigned) `fullName` data. The
        # Flutter app passes that along as `full_name` in the request
        # body instead, since this token alone can't provide it.
        full_name=None,
    )
