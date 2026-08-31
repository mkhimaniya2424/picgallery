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
@app.get("/gallery/{share_id}", include_in_schema=False)
def shared_web_fallback(share_id: str):
    """Web fallback for shared gallery links when opened in a browser without app installed.

    Redirects to the app via a custom-scheme/intent handoff, and only falls
    back to the Play Store link if that handoff genuinely didn't work.

    This used to fire `setTimeout(..., 1500)` unconditionally, sending the
    browser tab to the Play Store 1.5s after *every* load regardless of
    whether the app actually opened. The first time someone tapped a share
    link that redirect was harmless — the app took over and nobody was
    looking at the tab when it fired in the background. But the tab itself
    kept running that timer and always ended up parked on the Play Store
    page. The next time the *same* link was opened (some browsers/in-app
    browsers, e.g. WhatsApp's, reuse the existing tab for a link they
    already have open instead of loading a fresh page), the visitor landed
    back on that already-redirected Play Store tab instead of a fresh
    attempt to open the gallery — which looked like the link had simply
    stopped working.

    Fixed by only redirecting to the store once we can tell the app
    handoff didn't stick (via the Page Visibility API), and by re-checking
    on each visit rather than a blind one-shot timer.
    """
    from fastapi.responses import HTMLResponse

    safe_share_id = share_id.replace("\\", "\\\\").replace('"', '\\"')

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
    <p id="status-text">Opening shared gallery in app...</p>
    <a id="download-btn" class="btn" style="display:none" href="https://play.google.com/store/apps/details?id=com.mk.picgallery">Get PicGallery on Play Store</a>
  </div>
  <script>
    (function () {{
      var shareId = "{safe_share_id}";
      var ua = navigator.userAgent || "";
      var isAndroid = /Android/i.test(ua);
      var isIOS = /iPhone|iPad|iPod/i.test(ua);
      var playStoreUrl = "https://play.google.com/store/apps/details?id=com.mk.picgallery";
      var statusText = document.getElementById("status-text");
      var downloadBtn = document.getElementById("download-btn");

      var appLikelyOpened = false;
      var fallbackShown = false;

      function showFallback() {{
        if (appLikelyOpened || document.hidden || fallbackShown) return;
        fallbackShown = true;
        statusText.textContent = "Don't have the app yet?";
        downloadBtn.style.display = "inline-block";
      }}

      // Only treat the store link as a real fallback destination for
      // platforms it actually makes sense on — never auto-navigate an
      // iOS/desktop visitor to an Android Play Store page.
      function maybeAutoRedirectToStore() {{
        if (isAndroid) window.location.href = playStoreUrl;
      }}

      document.addEventListener("visibilitychange", function () {{
        if (document.hidden) {{
          appLikelyOpened = true;
          return;
        }}
        // Back on this tab. If we assumed the app took over but never
        // actually showed the fallback, the handoff likely didn't stick
        // (app not installed, or the OS just flashed a chooser dialog) —
        // retry instead of leaving the page stuck showing nothing.
        if (appLikelyOpened && !fallbackShown) {{
          appLikelyOpened = false;
          showFallback();
        }}
      }});

      function attemptAppHandoff() {{
        if (isAndroid) {{
          window.location.href =
            "intent://shared/" + encodeURIComponent(shareId) +
            "#Intent;scheme=https;package=com.mk.picgallery;S.browser_fallback_url=" +
            encodeURIComponent(playStoreUrl) + ";end";
        }} else if (isIOS) {{
          window.location.href = "picgallery://shared/" + encodeURIComponent(shareId);
        }}
      }}

      attemptAppHandoff();

      // Give the OS a moment to switch to the app before deciding it
      // didn't work — re-checked on every visit (see visibilitychange
      // above), not just once, so revisiting this same tab always gets a
      // fresh attempt instead of a page frozen on a stale timeout result.
      setTimeout(showFallback, 1500);
    }})();
  </script>
</body>
</html>"""
    return HTMLResponse(content=html_content)