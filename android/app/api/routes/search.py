from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_studio_user
from app.db.session import get_db
from app.models.gallery import Album, Folder, Media, MediaType
from app.models.user import User
from app.schemas.search import SearchResultRead, SearchResultType

router = APIRouter(prefix="/search", tags=["search"])

# Per-content-type cap on a single search — keeps one type (e.g. a
# studio with 5,000 photos) from drowning out Albums/Folders in the
# combined result list, same reasoning as most list endpoints' page size.
_RESULT_LIMIT = 30


@router.get("", response_model=list[SearchResultRead])
def global_search(
    q: str = Query(default="", description="Search term. A blank term returns no results."),
    type_filter: SearchResultType | None = Query(default=None, alias="type"),
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> list[SearchResultRead]:
    """Studio-only Global Search across Albums, Folders, and Media
    (Photos/Videos) — the real backend for `search_screen.dart` /
    `search_results_screen.dart`, previously served by
    `InMemorySearchRepository` (an always-empty in-memory stub with no
    route behind it at all).

    Matching is plain case-insensitive `ILIKE '%term%'` rather than
    Postgres full-text search (`tsvector`/`to_tsquery`): the searchable
    fields are short proper nouns (album/folder/file names), not prose,
    so stemming/ranking wouldn't add anything useful, and `ILIKE`
    already does case-insensitive substring matching without a
    migration to add generated `tsvector` columns/indexes. Revisit if
    free-text fields (e.g. media captions) ever become searchable.

    A blank query returns nothing — matches `InMemorySearchRepository`'s
    "starts empty" behavior before anything is typed, rather than
    dumping every item the studio owns.
    """
    term = q.strip()
    if not term:
        return []

    pattern = f"%{term}%"
    results: list[SearchResultRead] = []

    if type_filter is None or type_filter == SearchResultType.album:
        albums = (
            db.execute(
                select(Album)
                .where(Album.owner_id == current_user.id, Album.name.ilike(pattern))
                .order_by(Album.updated_at.desc())
                .limit(_RESULT_LIMIT)
            )
            .scalars()
            .all()
        )
        results.extend(
            SearchResultRead(id=album.id, type=SearchResultType.album, title=album.name, subtitle="Album")
            for album in albums
        )

    if type_filter is None or type_filter == SearchResultType.folder:
        folders = (
            db.execute(
                select(Folder)
                .where(Folder.owner_id == current_user.id, Folder.name.ilike(pattern))
                .order_by(Folder.updated_at.desc())
                .limit(_RESULT_LIMIT)
            )
            .scalars()
            .all()
        )
        results.extend(
            SearchResultRead(id=folder.id, type=SearchResultType.folder, title=folder.name, subtitle="Folder")
            for folder in folders
        )

    if type_filter in (None, SearchResultType.photo, SearchResultType.video):
        media_type = {
            SearchResultType.photo: MediaType.photo,
            SearchResultType.video: MediaType.video,
        }.get(type_filter)

        stmt = select(Media).where(
            Media.owner_id == current_user.id,
            Media.is_deleted.is_(False),
            Media.file_name.ilike(pattern),
        )
        if media_type is not None:
            stmt = stmt.where(Media.media_type == media_type)
        stmt = stmt.order_by(Media.updated_at.desc()).limit(_RESULT_LIMIT)

        media_items = db.execute(stmt).scalars().all()
        results.extend(
            SearchResultRead(
                id=media.id,
                type=SearchResultType.photo if media.media_type == MediaType.photo else SearchResultType.video,
                title=media.file_name,
                subtitle="Photo" if media.media_type == MediaType.photo else "Video",
            )
            for media in media_items
        )

    return results


@router.get("/suggestions", response_model=list[str])
def search_suggestions(
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> list[str]:
    """Suggested terms shown while the search field is empty or only
    partially typed — the studio's own most recently touched Album and
    Folder names, deduplicated and capped at 8 (mirrors
    `recentSearchesProvider`'s own cap on the Flutter side). No
    canned/hardcoded suggestions; a brand-new studio with no
    Albums/Folders gets an empty list, same as before.
    """
    albums = (
        db.execute(
            select(Album.name)
            .where(Album.owner_id == current_user.id)
            .order_by(Album.updated_at.desc())
            .limit(6)
        )
        .scalars()
        .all()
    )
    folders = (
        db.execute(
            select(Folder.name)
            .where(Folder.owner_id == current_user.id)
            .order_by(Folder.updated_at.desc())
            .limit(6)
        )
        .scalars()
        .all()
    )

    seen: set[str] = set()
    suggestions: list[str] = []
    for name in [*albums, *folders]:
        key = name.lower()
        if key in seen:
            continue
        seen.add(key)
        suggestions.append(name)
        if len(suggestions) == 8:
            break
    return suggestions
