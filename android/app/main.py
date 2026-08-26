from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.routes import api_router
from app.core.config import settings

app = FastAPI(title=settings.PROJECT_NAME)

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
