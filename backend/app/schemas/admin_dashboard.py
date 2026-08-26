from pydantic import BaseModel


class AdminDashboardStatsRead(BaseModel):
    """Real, DB-backed headline numbers for the Admin Dashboard.

    Replaces the numbers `InMemoryAdminDashboardRepository._deriveStats()`
    used to fabricate on the Flutter side. Everything here is computed
    live from the current studio's own rows — no cached counters, so
    nothing can drift out of sync with the underlying tables.
    """

    # Media
    photo_count: int
    video_count: int
    total_media_count: int

    # Storage
    storage_used_bytes: int
    storage_used_gb: float

    # Clients — accepted studio<->client connections only, i.e. people
    # actually connected to this studio, not every client account that
    # ever exists in the system.
    client_count: int
    pending_client_requests: int

    # Galleries
    shared_gallery_count: int
    # Total gallery views (sum of ShareLink.views_count for non-revoked
    # links) and total downloads (DownloadEvent row count) for this studio.
    # Neither is split per-client at this layer — see /client-stats for that.
    total_gallery_views: int = 0
    total_gallery_downloads: int = 0


class ClientStatsRead(BaseModel):
    """Per-client aggregate stats for the Admin Dashboard Views/Downloads
    tabs.  ``client_id`` is the UUID string of the connected client user.

    ``total_downloads`` counts ``DownloadEvent`` rows where
    ``downloaded_by_user_id`` matches the client and ``owner_id`` matches
    the studio.  ``total_views`` sums the ``views_count`` column of all
    non-revoked ``ShareLink`` rows owned by this studio — the schema
    does not record *which* viewer opened a link, so views are a
    studio-wide total that cannot (yet) be split per client; this field
    therefore always returns 0 until per-viewer tracking lands.
    """

    client_id: str
    total_views: int = 0
    total_downloads: int = 0
    assigned_gallery_ids: list[str] = []


class ClientStatsListRead(BaseModel):
    items: list[ClientStatsRead]
