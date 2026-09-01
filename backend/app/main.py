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
    """Serves the Android Digital Asset Links file for Android App Link verification.
    NOTE: For Play Store builds, add the Google Play App Signing SHA-256 fingerprint here
    and in web/.well-known/assetlinks.json. Get it from: Play Console -> Setup -> App integrity -> App signing.
    Without the correct Play signing cert, autoVerify will fail for release builds."""
    from fastapi.responses import JSONResponse

    return JSONResponse(
        content=[
            {
                "relation": ["delegate_permission/common.handle_all_urls"],
                "target": {
                    "namespace": "android_app",
                    "package_name": "com.mk.picgallery",
                    "sha256_cert_fingerprints": [
                        "B6:C8:1E:76:C4:04:9E:19:4D:7C:1D:88:D7:30:E0:D1:F5:3A:DA:BB:A7:12:FA:BC:3B:21:CB:CF:E2:59:72:7B",
                        "FA:C6:17:45:DC:09:03:78:6F:B9:ED:E6:2A:96:2B:39:9F:73:48:F0:BB:6F:89:9B:83:32:66:75:91:03:3B:9C",
                        "E7:A9:B2:91:6F:F9:70:70:DA:55:6E:81:61:90:72:7E:19:AF:CE:13:3B:A0:8F:72:55:77:89:C4:2F:2A:78:52"
                    ],
                },
            }
        ]
    )


@app.get("/shared/{share_id}", include_in_schema=False)
@app.get("/gallery/{share_id}", include_in_schema=False)
def shared_web_fallback(share_id: str):
    """Web Client Gallery SPA for shared links when opened in a web browser without the app installed."""
    from fastapi.responses import HTMLResponse

    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>PicGallery — Client Gallery</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    * {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0b0f19; color: #f8fafc; min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: flex-start; }}
    .header {{ width: 100%; max-width: 1200px; padding: 1.25rem 1.5rem; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #1e293b; background: #0f172a; position: sticky; top: 0; z-index: 50; }}
    .brand {{ display: flex; align-items: center; gap: 0.75rem; text-decoration: none; color: #fff; font-weight: 800; font-size: 1.25rem; }}
    .brand-icon {{ width: 36px; height: 36px; background: linear-gradient(135deg, #6366f1, #a855f7); border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 1.2rem; }}
    .btn-app {{ background: rgba(99, 102, 241, 0.15); border: 1px solid rgba(99, 102, 241, 0.4); color: #818cf8; text-decoration: none; padding: 0.5rem 1rem; border-radius: 0.5rem; font-size: 0.85rem; font-weight: 700; transition: all 0.2s; }}
    .btn-app:hover {{ background: rgba(99, 102, 241, 0.25); color: #fff; }}

    .main-container {{ width: 100%; max-width: 1200px; padding: 2rem 1.5rem; flex: 1; display: flex; flex-direction: column; align-items: center; }}
    .card {{ background: #1e293b; border: 1px solid #334155; padding: 2.5rem 2rem; border-radius: 1.25rem; max-width: 440px; width: 100%; box-shadow: 0 20px 40px rgba(0,0,0,0.6); text-align: center; margin-top: 3rem; }}
    .card-icon {{ font-size: 3rem; margin-bottom: 1rem; display: block; }}
    .card h2 {{ font-size: 1.5rem; color: #fff; margin-bottom: 0.5rem; font-weight: 800; }}
    .card p {{ font-size: 0.9rem; color: #94a3b8; margin-bottom: 1.5rem; line-height: 1.5; }}
    
    .form-group {{ display: flex; flex-direction: column; gap: 0.75rem; width: 100%; text-align: left; }}
    .form-group label {{ font-size: 0.8rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: #94a3b8; }}
    .input-field {{ background: #0f172a; border: 1px solid #334155; color: #fff; padding: 0.8rem 1rem; border-radius: 0.5rem; font-size: 1rem; outline: none; width: 100%; transition: border-color 0.2s; }}
    .input-field:focus {{ border-color: #6366f1; }}
    .btn-submit {{ background: linear-gradient(135deg, #6366f1, #a855f7); color: #fff; border: none; padding: 0.85rem 1.5rem; border-radius: 0.5rem; font-size: 0.95rem; font-weight: 700; cursor: pointer; width: 100%; margin-top: 0.5rem; transition: opacity 0.2s; }}
    .btn-submit:hover {{ opacity: 0.9; }}
    .error-msg {{ color: #f87171; font-size: 0.85rem; font-weight: 600; margin-top: 0.5rem; display: none; }}

    .gallery-header {{ width: 100%; text-align: left; margin-bottom: 2rem; border-bottom: 1px solid #1e293b; padding-bottom: 1.5rem; }}
    .gallery-header h1 {{ font-size: 2rem; font-weight: 800; color: #fff; margin-bottom: 0.5rem; }}
    .gallery-header p {{ color: #94a3b8; font-size: 0.95rem; line-height: 1.5; }}
    .gallery-stats {{ margin-top: 0.75rem; font-size: 0.85rem; font-weight: 600; color: #818cf8; display: inline-block; background: rgba(99,102,241,0.12); padding: 0.3rem 0.75rem; border-radius: 1rem; }}

    .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 1rem; width: 100%; }}
    .grid-item {{ aspect-ratio: 1 / 1; border-radius: 0.75rem; overflow: hidden; background: #1e293b; position: relative; cursor: pointer; border: 1px solid #334155; transition: transform 0.2s, box-shadow 0.2s; }}
    .grid-item:hover {{ transform: translateY(-4px); box-shadow: 0 12px 24px rgba(0,0,0,0.5); }}
    .grid-item img {{ width: 100%; height: 100%; object-fit: cover; }}

    .lightbox {{ display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.92); z-index: 100; align-items: center; justify-content: center; flex-direction: column; padding: 1.5rem; }}
    .lightbox img {{ max-width: 90vw; max-height: 80vh; object-fit: contain; border-radius: 0.5rem; }}
    .lightbox-close {{ position: absolute; top: 1.5rem; right: 1.5rem; color: #fff; font-size: 2rem; cursor: pointer; border: none; background: none; }}
    .spinner {{ width: 40px; height: 40px; border: 4px solid rgba(255,255,255,0.1); border-left-color: #6366f1; border-radius: 50%; animation: spin 1s linear infinite; margin-top: 4rem; }}
    @keyframes spin {{ to {{ transform: rotate(360deg); }} }}
  </style>
</head>
<body>
  <header class="header">
    <a href="#" class="brand">
      <div class="brand-icon">📷</div>
      <span>PicGallery</span>
    </a>
    <a id="open-app-btn" href="https://picgallery.in/gallery/{share_id}" class="btn-app">Open in PicGallery App</a>
  </header>

  <main class="main-container">
    <div id="loader" class="spinner"></div>

    <div id="card-view" class="card" style="display:none;">
      <span id="card-icon" class="card-icon">🔒</span>
      <h2 id="card-title">Private Gallery</h2>
      <p id="card-desc">Enter the passcode provided by the studio to view this gallery.</p>

      <form id="passcode-form" class="form-group" style="display:none;" onsubmit="handleUnlock(event)">
        <label for="passcode-input">Passcode</label>
        <input type="password" id="passcode-input" class="input-field" placeholder="Enter gallery passcode" required autocomplete="off" />
        <button type="submit" class="btn-submit">Unlock Gallery</button>
        <div id="error-msg" class="error-msg">Incorrect passcode. Please try again.</div>
      </form>
    </div>

    <div id="gallery-view" style="display:none; width: 100%;">
      <div class="gallery-header">
        <h1 id="gallery-title">Gallery</h1>
        <p id="gallery-desc"></p>
        <div id="gallery-count" class="gallery-stats">0 photos</div>
      </div>
      <div id="photo-grid" class="grid"></div>
    </div>
  </main>

  <div id="lightbox" class="lightbox" onclick="closeLightbox(event)">
    <button class="lightbox-close" onclick="closeLightbox(event)">&times;</button>
    <img id="lightbox-img" src="" alt="Full preview" />
  </div>

  <script>
    const shareToken = "{share_id}";
    const apiBase = "/api/v1/public/galleries/";

    async function loadGallery(password = "") {{
      const loader = document.getElementById("loader");
      const cardView = document.getElementById("card-view");
      const galleryView = document.getElementById("gallery-view");
      const errorMsg = document.getElementById("error-msg");

      loader.style.display = "block";
      cardView.style.display = "none";
      galleryView.style.display = "none";

      try {{
        let url = apiBase + shareToken;
        if (password) url += "?password=" + encodeURIComponent(password);
        
        const res = await fetch(url);
        const data = await res.json();

        loader.style.display = "none";

        if (res.status === 401) {{
          // Password required or invalid password
          cardView.style.display = "block";
          document.getElementById("passcode-form").style.display = "flex";
          if (password) {{
            errorMsg.style.display = "block";
            errorMsg.innerText = "Incorrect passcode. Please try again.";
          }}
          return;
        }}

        if (res.status === 410) {{
          cardView.style.display = "block";
          document.getElementById("card-icon").innerText = "⏳";
          document.getElementById("card-title").innerText = "Gallery Unavailable";
          document.getElementById("card-desc").innerText = data.detail || "This gallery link has expired or been revoked.";
          return;
        }}

        if (res.status === 404) {{
          cardView.style.display = "block";
          document.getElementById("card-icon").innerText = "🔍";
          document.getElementById("card-title").innerText = "Gallery Not Found";
          document.getElementById("card-desc").innerText = "This gallery link is invalid or no longer exists.";
          return;
        }}

        if (!res.ok) {{
          cardView.style.display = "block";
          document.getElementById("card-title").innerText = "Error Loading Gallery";
          document.getElementById("card-desc").innerText = data.detail || "Could not load gallery. Please try again.";
          return;
        }}

        // Successfully loaded gallery!
        renderGallery(data);

      }} catch (e) {{
        loader.style.display = "none";
        cardView.style.display = "block";
        document.getElementById("card-title").innerText = "Connection Error";
        document.getElementById("card-desc").innerText = "Failed to connect to the server. Check your connection.";
      }}
    }}

    function handleUnlock(e) {{
      e.preventDefault();
      const pwd = document.getElementById("passcode-input").value;
      if (pwd) loadGallery(pwd);
    }}

    function renderGallery(data) {{
      document.getElementById("gallery-view").style.display = "block";
      document.getElementById("gallery-title").innerText = data.album ? data.album.name : "Shared Gallery";
      document.getElementById("gallery-desc").innerText = data.album && data.album.description ? data.album.description : "";
      
      const mediaList = data.media || [];
      document.getElementById("gallery-count").innerText = mediaList.length + " photos";

      const grid = document.getElementById("photo-grid");
      grid.innerHTML = "";

      mediaList.forEach(m => {{
        const item = document.createElement("div");
        item.className = "grid-item";
        const imgUrl = m.file_path.startsWith("http") ? m.file_path : "/media/" + m.file_path;
        item.innerHTML = `<img src="${{imgUrl}}" alt="${{m.file_name}}" loading="lazy" />`;
        item.onclick = () => openLightbox(imgUrl);
        grid.appendChild(item);
      }});
    }}

    function openLightbox(url) {{
      document.getElementById("lightbox-img").src = url;
      document.getElementById("lightbox").style.display = "flex";
    }}

    function closeLightbox(e) {{
      document.getElementById("lightbox").style.display = "none";
    }}

    // Initial load
    loadGallery();
  </script>
</body>
</html>"""
    return HTMLResponse(content=html_content)