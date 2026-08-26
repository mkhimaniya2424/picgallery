import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_studio_user
from app.db.session import get_db
from app.models.gallery import Album, CollectionItem, GalleryCollection
from app.models.user import User
from app.schemas.gallery import (
    CollectionAlbumAddRequest,
    CollectionAlbumReorderRequest,
    CollectionCreate,
    CollectionRead,
    CollectionReorderRequest,
    CollectionUpdate,
)
from app.schemas.user import MessageResponse

router = APIRouter(prefix="/collections", tags=["gallery-collections"])


def _get_owned_collection(db: Session, collection_id: uuid.UUID, owner_id: uuid.UUID) -> GalleryCollection:
    collection = db.get(GalleryCollection, collection_id)
    if collection is None or collection.owner_id != owner_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Collection not found")
    return collection


def _gallery_ids(db: Session, collection_id: uuid.UUID) -> list[uuid.UUID]:
    rows = db.execute(
        select(CollectionItem.album_id)
        .where(CollectionItem.collection_id == collection_id)
        .order_by(CollectionItem.position.asc())
    ).scalars().all()
    return list(rows)


def _gallery_ids_bulk(db: Session, owner_id: uuid.UUID) -> dict[uuid.UUID, list[uuid.UUID]]:
    """One query for every owned collection's ordered album ids —
    avoids N+1 queries on the list endpoint (same reasoning as
    albums.py's `_media_counts`).
    """
    rows = db.execute(
        select(CollectionItem.collection_id, CollectionItem.album_id)
        .join(GalleryCollection, GalleryCollection.id == CollectionItem.collection_id)
        .where(GalleryCollection.owner_id == owner_id)
        .order_by(CollectionItem.collection_id, CollectionItem.position.asc())
    ).all()
    out: dict[uuid.UUID, list[uuid.UUID]] = {}
    for collection_id, album_id in rows:
        out.setdefault(collection_id, []).append(album_id)
    return out


@router.post("", response_model=CollectionRead, status_code=status.HTTP_201_CREATED)
def create_collection(
    payload: CollectionCreate,
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> CollectionRead:
    max_order = db.execute(
        select(func.max(GalleryCollection.display_order)).where(GalleryCollection.owner_id == current_user.id)
    ).scalar()

    collection = GalleryCollection(
        owner_id=current_user.id,
        name=payload.name,
        display_order=(max_order or 0) + 1,
    )
    db.add(collection)
    db.commit()
    db.refresh(collection)
    return CollectionRead.from_model(collection, [])


@router.get("", response_model=list[CollectionRead])
def list_collections(
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> list[CollectionRead]:
    collections = db.execute(
        select(GalleryCollection)
        .where(GalleryCollection.owner_id == current_user.id)
        .order_by(GalleryCollection.display_order.asc(), GalleryCollection.created_at.desc())
    ).scalars().all()
    ids_by_collection = _gallery_ids_bulk(db, current_user.id)
    return [
        CollectionRead.from_model(c, ids_by_collection.get(c.id, []))
        for c in collections
    ]


@router.get("/{collection_id}", response_model=CollectionRead)
def get_collection(
    collection_id: uuid.UUID,
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> CollectionRead:
    collection = _get_owned_collection(db, collection_id, current_user.id)
    return CollectionRead.from_model(collection, _gallery_ids(db, collection.id))


@router.patch("/{collection_id}", response_model=CollectionRead)
def update_collection(
    collection_id: uuid.UUID,
    payload: CollectionUpdate,
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> CollectionRead:
    collection = _get_owned_collection(db, collection_id, current_user.id)
    updates = payload.model_dump(exclude_unset=True)

    if "name" in updates and updates["name"] is not None:
        collection.name = updates["name"]
    if "display_order" in updates and updates["display_order"] is not None:
        collection.display_order = updates["display_order"]

    db.commit()
    db.refresh(collection)
    return CollectionRead.from_model(collection, _gallery_ids(db, collection.id))


@router.post("/reorder", response_model=list[CollectionRead])
def reorder_collections(
    payload: CollectionReorderRequest,
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> list[CollectionRead]:
    """Bulk-updates `display_order` for the given collections in one
    request (drag-to-reorder on the Collections list screen). Any
    collection id not owned by this studio is ignored rather than
    rejecting the whole batch — same convention as `POST /albums/reorder`.
    """
    for item in payload.items:
        collection = db.get(GalleryCollection, item.id)
        if collection is not None and collection.owner_id == current_user.id:
            collection.display_order = item.display_order
    db.commit()

    collections = db.execute(
        select(GalleryCollection)
        .where(GalleryCollection.owner_id == current_user.id)
        .order_by(GalleryCollection.display_order.asc())
    ).scalars().all()
    ids_by_collection = _gallery_ids_bulk(db, current_user.id)
    return [
        CollectionRead.from_model(c, ids_by_collection.get(c.id, []))
        for c in collections
    ]


@router.delete("/{collection_id}", response_model=MessageResponse)
def delete_collection(
    collection_id: uuid.UUID,
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> MessageResponse:
    """Deletes the collection itself. The albums it contained are
    untouched — only the grouping (its `CollectionItem` rows) goes
    away, via the FK's ON DELETE CASCADE.
    """
    collection = _get_owned_collection(db, collection_id, current_user.id)
    db.delete(collection)
    db.commit()
    return MessageResponse(message="Collection deleted.")


# ---------------------------------------------------------------------------
# Album membership within a collection
# ---------------------------------------------------------------------------


@router.post("/{collection_id}/albums", response_model=CollectionRead)
def add_albums_to_collection(
    collection_id: uuid.UUID,
    payload: CollectionAlbumAddRequest,
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> CollectionRead:
    collection = _get_owned_collection(db, collection_id, current_user.id)
    existing_ids = set(_gallery_ids(db, collection.id))

    next_position = db.execute(
        select(CollectionItem.position)
        .where(CollectionItem.collection_id == collection.id)
        .order_by(CollectionItem.position.desc())
        .limit(1)
    ).scalar()
    next_position = (next_position + 1) if next_position is not None else 0

    for album_id in payload.album_ids:
        if album_id in existing_ids:
            continue
        album = db.get(Album, album_id)
        if album is None or album.owner_id != current_user.id:
            continue
        db.add(CollectionItem(collection_id=collection.id, album_id=album_id, position=next_position))
        existing_ids.add(album_id)
        next_position += 1

    db.commit()
    return CollectionRead.from_model(collection, _gallery_ids(db, collection.id))


@router.delete("/{collection_id}/albums/{album_id}", response_model=CollectionRead)
def remove_album_from_collection(
    collection_id: uuid.UUID,
    album_id: uuid.UUID,
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> CollectionRead:
    collection = _get_owned_collection(db, collection_id, current_user.id)

    item = db.execute(
        select(CollectionItem).where(
            CollectionItem.collection_id == collection.id, CollectionItem.album_id == album_id
        )
    ).scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Album is not in this collection")

    db.delete(item)
    db.commit()

    # Re-sequence remaining positions to a clean 0..n-1 run so gaps
    # from removals never accumulate.
    remaining = db.execute(
        select(CollectionItem)
        .where(CollectionItem.collection_id == collection.id)
        .order_by(CollectionItem.position.asc())
    ).scalars().all()
    for i, row in enumerate(remaining):
        row.position = i
    db.commit()

    return CollectionRead.from_model(collection, _gallery_ids(db, collection.id))


@router.post("/{collection_id}/albums/reorder", response_model=CollectionRead)
def reorder_collection_albums(
    collection_id: uuid.UUID,
    payload: CollectionAlbumReorderRequest,
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> CollectionRead:
    """Full replacement of album order within this one collection —
    `album_ids` must be exactly the current membership, reordered.
    """
    collection = _get_owned_collection(db, collection_id, current_user.id)

    items = db.execute(
        select(CollectionItem).where(CollectionItem.collection_id == collection.id)
    ).scalars().all()
    by_album_id = {item.album_id: item for item in items}

    if set(payload.album_ids) != set(by_album_id.keys()):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="album_ids must contain exactly the albums currently in this collection.",
        )

    for position, album_id in enumerate(payload.album_ids):
        by_album_id[album_id].position = position

    db.commit()
    return CollectionRead.from_model(collection, _gallery_ids(db, collection.id))
