from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.api.routes import api_router
from app.core.config import settings

app = FastAPI(title=settings.PROJECT_NAME)

_STATIC_DIR = Path(__file__).parent / "static"
_SHARE_LANDING_PAGE = _STATIC_DIR / "shared-link-landing.html"

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_PREFIX)

# Serves every uploaded original/thumbnail under MEDIA_URL_PREFIX, e.g.
# a file saved at "<owner_id>/<media_id>/original.jpg" becomes reachable
# at f"{APP_PUBLIC_URL}{MEDIA_URL_PREFIX}/<owner_id>/<media_id>/original.jpg".
# See core/storage.py for the write side of this. Only needed for the
# "local" storage backend — when STORAGE_BACKEND="r2", files are served
# directly from R2_PUBLIC_URL instead, bypassing this process entirely.
if settings.STORAGE_BACKEND == "local":
    _media_root = Path(settings.MEDIA_STORAGE_DIR)
    _media_root.mkdir(parents=True, exist_ok=True)
    app.mount(settings.MEDIA_URL_PREFIX, StaticFiles(directory=str(_media_root)), name="media")


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}


# ---------------------------------------------------------------------------
# Share link landing page — what a WhatsApp/etc. tap on a share link
# (SHARE_LINK_BASE_URL + SHARE_LINK_PATH_PREFIX + "/" + token, see
# core/storage.build_share_url) actually opens in a browser.
#
# Serving it from this API means no separate website/hosting is needed:
# point SHARE_LINK_BASE_URL at wherever this service is reachable
# (e.g. https://api.picgallery.in) and every share link will hit this
# route. The page itself (app/static/shared-link-landing.html) reads the
# token from the URL client-side and:
#   - tries to hand off to the installed app (Android intent:// URL,
#     which also carries its own Play Store fallback baked in),
#   - if that doesn't happen within ~1.5s, calls
#     /api/v1/public/share-links/{token}/status and either shows a
#     preview (public + active), a "get the app to unlock it" prompt
#     (password-protected), or an expired/revoked message.
#
# Registered directly (not via StaticFiles) so the path has no file
# extension and matches SHARE_LINK_PATH_PREFIX exactly.
@app.get("/shared/{token}", include_in_schema=False)
def shared_link_landing(token: str) -> FileResponse:
    return FileResponse(_SHARE_LANDING_PAGE, media_type="text/html")
