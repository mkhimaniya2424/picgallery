import logging
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.api.routes import api_router
from app.core.config import settings

# Root logging config — without this, logger.exception(...) calls
# scattered through the app (including the global handler below) have
# no guaranteed destination: Python's logging module only falls back
# to a bare "handler of last resort" on stderr, with no timestamps,
# module name, or reliable capture under a process manager like NSSM.
# This makes every log line explicit and consistently formatted,
# wherever NSSM's stdout/stderr redirection is pointed.
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)

logger = logging.getLogger(__name__)

app = FastAPI(title=settings.PROJECT_NAME)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Safety net for every route in the app. Without this, an
    unhandled exception anywhere (a missing config value, a DB
    constraint, a bug in a new endpoint, etc.) falls through to
    Starlette's built-in default: a bare "Internal Server Error"
    with the real cause visible nowhere — not in the app, not in any
    log, since nothing was logging it. This catches it, logs the full
    traceback (so the actual cause shows up in the server's log
    output instead of vanishing), and returns the same
    `{"detail": "..."}` shape every other error already uses, so the
    Flutter app's `ApiException` parsing keeps working unchanged.
    """
    logger.exception("Unhandled exception on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "Something went wrong on our end. Please try again."},
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


@app.get("/.well-known/assetlinks.json", include_in_schema=False)
def get_asset_links():
    """Serves the Android Digital Asset Links file for Android App Link verification."""
    from fastapi.responses import JSONResponse

    return JSONResponse(
        content=[
            {
                "relation": ["delegate_permission/common.handle_all_urls"],
                "target": {
                    "namespace": "android_app",
                    "package_name": "com.mk.picgallery",
                    "sha256_cert_fingerprints": [
                        "B6:C8:1E:76:C4:04:9E:19:4D:7C:1D:88:D7:30:E0:D1:F5:3A:DA:BB:A7:12:FA:BC:3B:21:CB:CF:E2:59:72:7B"
                    ],
                },
            }
        ]
    )


@app.get("/shared/{share_id}", include_in_schema=False)
def shared_web_fallback(share_id: str):
    """Web fallback for shared gallery links when opened in a browser without app installed."""
    from fastapi.responses import HTMLResponse

    html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>PicGallery - Shared Gallery</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #0f172a; color: #f8fafc; text-align: center; }}
    .card {{ background: #1e293b; padding: 2.5rem 2rem; border-radius: 1rem; max-width: 400px; width: 90%; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }}
    h1 {{ font-size: 1.5rem; margin-bottom: 0.5rem; color: #fff; }}
    p {{ font-size: 0.9rem; color: #94a3b8; margin-bottom: 1.5rem; line-height: 1.5; }}
    .btn {{ display: inline-block; background: linear-gradient(135deg, #6366f1, #a855f7); color: #fff; text-decoration: none; padding: 0.8rem 1.6rem; border-radius: 0.5rem; font-weight: 600; font-size: 0.9rem; transition: opacity 0.2s; }}
    .btn:hover {{ opacity: 0.9; }}
  </style>
</head>
<body>
  <div class="card">
    <h1>PicGallery</h1>
    <p>Opening shared gallery in app...</p>
    <a id="download-btn" class="btn" href="https://play.google.com/store/apps/details?id=com.mk.picgallery">Get PicGallery on Play Store</a>
  </div>
  <script>
    const appUrl = "picgallery://shared/{share_id}";
    const playStoreUrl = "https://play.google.com/store/apps/details?id=com.mk.picgallery";
    window.location.href = appUrl;
    setTimeout(function() {{
      window.location.href = playStoreUrl;
    }}, 1500);
  </script>
</body>
</html>"""
    return HTMLResponse(content=html_content)