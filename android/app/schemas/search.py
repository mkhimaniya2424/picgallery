import enum
import uuid

from pydantic import BaseModel, ConfigDict


class SearchResultType(str, enum.Enum):
    """Mirrors Flutter's `SearchResultType` enum in `search_data.dart` —
    Global Search covers exactly these four content kinds, each with
    its own icon/gradient on the client.
    """

    album = "album"
    photo = "photo"
    video = "video"
    folder = "folder"


class SearchResultRead(BaseModel):
    """One row in a Global Search result list. Deliberately flat/generic
    (id + type + title + subtitle) rather than a union of
    Album/Media/Folder read schemas — the search results screen only
    ever renders a title/subtitle/icon per `SearchResultTile`, so there's
    nothing gained by exposing each type's full shape here; the client
    can fetch full details after tapping through.
    """

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    type: SearchResultType
    title: str
    subtitle: str
