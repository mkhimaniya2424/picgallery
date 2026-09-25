import logging
import shutil
import tempfile
import uuid
from pathlib import Path
from typing import List

from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, UploadFile, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.deps import require_active_plan
from app.core.activity_log import log_activity
from app.core.config import settings
from app.core.face_index import index_media_background
from app.core.storage import (
    _r2_client,
    _storage_root,
    _use_r2,
    media_type_for_content_type,
)
from app.db.session import get_db
from app.models.activity_log import ActivityType
from app.models.gallery import Album, Folder, Media, MediaType
from app.models.user import User
from app.schemas.gallery import MediaRead

# We import this function to reuse the background metadata extraction
from app.api.routes.media import _generate_thumbnail_background

router = APIRouter(prefix="/media/chunked", tags=["chunked-upload"])
logger = logging.getLogger(__name__)


class ChunkedStartRequest(BaseModel):
    filename: str
    content_type: str
    total_size: int
    total_parts: int


class ChunkedStartResponse(BaseModel):
    upload_id: str
    media_id: uuid.UUID
    part_urls: List[str] | None = None


class S3Part(BaseModel):
    PartNumber: int
    ETag: str


class ChunkedCompleteRequest(BaseModel):
    upload_id: str
    media_id: uuid.UUID
    filename: str
    content_type: str
    total_size: int
    parts: List[S3Part] | None = None
    album_id: uuid.UUID | None = None
    folder_id: uuid.UUID | None = None


class ChunkedResumeRequest(BaseModel):
    upload_id: str
    media_id: uuid.UUID
    filename: str
    total_parts: int


class ChunkedResumeResponse(BaseModel):
    part_urls: List[str] | None = None
    uploaded_parts: List[int]


class ChunkedAbortRequest(BaseModel):
    upload_id: str
    media_id: uuid.UUID
    filename: str


@router.post("/start", response_model=ChunkedStartResponse)
def start_chunked_upload(
    req: ChunkedStartRequest,
    current_user: User = Depends(require_active_plan),
):
    """
    Initializes a multipart upload. 
    If R2 is configured, it returns presigned URLs for each part.
    If Local storage is configured, it returns an upload_id for local chunks.
    """
    try:
        media_type = media_type_for_content_type(req.content_type)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if settings.MAX_UPLOAD_SIZE_BYTES and req.total_size > settings.MAX_UPLOAD_SIZE_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Maximum size is {settings.MAX_UPLOAD_SIZE_BYTES} bytes."
        )

    media_id = uuid.uuid4()
    suffix = Path(req.filename).suffix if req.filename else ".bin"
    relative_path = f"{current_user.id}/{media_id}/original{suffix}"

    if _use_r2():
        s3 = _r2_client()
        try:
            res = s3.create_multipart_upload(
                Bucket=settings.R2_BUCKET_NAME,
                Key=relative_path,
                ContentType=req.content_type,
            )
            upload_id = res["UploadId"]

            part_urls = []
            for i in range(1, req.total_parts + 1):
                url = s3.generate_presigned_url(
                    "upload_part",
                    Params={
                        "Bucket": settings.R2_BUCKET_NAME,
                        "Key": relative_path,
                        "UploadId": upload_id,
                        "PartNumber": i,
                    },
                    ExpiresIn=3600,
                )
                part_urls.append(url)

            return ChunkedStartResponse(
                upload_id=upload_id,
                media_id=media_id,
                part_urls=part_urls,
            )
        except Exception:
            logger.exception("Failed to start S3 multipart upload for %s", relative_path)
            raise HTTPException(status_code=500, detail="Failed to initialize storage upload.")
    else:
        # Local chunked upload
        upload_id = str(uuid.uuid4())
        chunk_dir = _storage_root() / "tmp" / upload_id
        chunk_dir.mkdir(parents=True, exist_ok=True)
        return ChunkedStartResponse(
            upload_id=upload_id,
            media_id=media_id,
            part_urls=None,
        )


@router.patch("/{upload_id}/{part_number}")
def upload_chunk_local(
    upload_id: str,
    part_number: int,
    file: UploadFile = File(...),
    current_user: User = Depends(require_active_plan),
):
    """
    Used only for local storage when R2 is disabled. 
    Receives a chunk and saves it in a temporary folder.
    """
    if _use_r2():
        raise HTTPException(
            status_code=400,
            detail="Server is configured for R2 direct uploads. Use the presigned URLs provided by /start instead.",
        )

    try:
        uuid_val = uuid.UUID(upload_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid upload_id format.")

    chunk_dir = _storage_root() / "tmp" / str(uuid_val)
    if not chunk_dir.exists():
        raise HTTPException(status_code=404, detail="Upload session not found.")

    chunk_path = chunk_dir / f"{part_number:05d}.part"
    try:
        with chunk_path.open("wb") as f:
            shutil.copyfileobj(file.file, f)
    except Exception:
        logger.exception("Failed to write chunk %s for upload_id %s", part_number, upload_id)
        raise HTTPException(status_code=500, detail="Failed to write chunk.")

    return {"status": "ok"}


@router.post("/complete", response_model=MediaRead, status_code=status.HTTP_201_CREATED)
def complete_chunked_upload(
    req: ChunkedCompleteRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(require_active_plan),
    db: Session = Depends(get_db),
):
    """
    Finalizes the chunked upload. 
    For R2, it calls complete_multipart_upload with the ETags.
    For local, it stitches the chunks together.
    Then saves the Media record and queues thumbnails.
    """
    if req.album_id is not None:
        album = db.get(Album, req.album_id)
        if album is None or album.owner_id != current_user.id:
            raise HTTPException(status_code=404, detail="Album not found")
    if req.folder_id is not None:
        folder = db.get(Folder, req.folder_id)
        if folder is None or folder.owner_id != current_user.id:
            raise HTTPException(status_code=404, detail="Folder not found")

    try:
        media_type = media_type_for_content_type(req.content_type)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    suffix = Path(req.filename).suffix if req.filename else ".bin"
    relative_path = f"{current_user.id}/{req.media_id}/original{suffix}"

    if _use_r2():
        if not req.parts:
            raise HTTPException(status_code=400, detail="parts with ETags are required for R2.")
        
        s3 = _r2_client()
        try:
            s3.complete_multipart_upload(
                Bucket=settings.R2_BUCKET_NAME,
                Key=relative_path,
                UploadId=req.upload_id,
                MultipartUpload={
                    "Parts": [p.model_dump() for p in req.parts]
                },
            )
        except Exception:
            logger.exception("Failed to complete S3 multipart upload %s", req.upload_id)
            raise HTTPException(status_code=500, detail="Failed to finalize storage upload.")
    else:
        # Local stitch
        try:
            uuid_val = uuid.UUID(req.upload_id)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid upload_id format.")
            
        chunk_dir = _storage_root() / "tmp" / str(uuid_val)
        if not chunk_dir.exists():
            raise HTTPException(status_code=404, detail="Upload session not found.")
        
        dest = _storage_root() / relative_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        
        try:
            parts = sorted(chunk_dir.glob("*.part"))
            if not parts:
                raise HTTPException(status_code=400, detail="No chunks found.")
            
            if req.parts and len(parts) != len(req.parts):
                raise HTTPException(status_code=400, detail="Uploaded chunks count does not match the requested parts count.")
                
            with dest.open("wb") as outfile:
                for part_path in parts:
                    with part_path.open("rb") as infile:
                        shutil.copyfileobj(infile, outfile)
                        
            if dest.stat().st_size != req.total_size:
                dest.unlink(missing_ok=True)
                raise HTTPException(status_code=400, detail="Stitched file size does not match expected total size.")
                        
            shutil.rmtree(chunk_dir, ignore_errors=True)
        except Exception:
            logger.exception("Failed to stitch local chunks for %s", req.upload_id)
            raise HTTPException(status_code=500, detail="Failed to assemble uploaded file.")

    try:
        media = Media(
            id=req.media_id,
            owner_id=current_user.id,
            album_id=req.album_id,
            folder_id=req.folder_id,
            media_type=media_type,
            file_name=req.filename or "upload",
            file_path=relative_path,
            thumbnail_path=None,
            content_type=req.content_type,
            size_bytes=req.total_size,
            width=None,
            height=None,
            duration_ms=None,
        )
        db.add(media)
        log_activity(
            db,
            studio_id=current_user.id,
            type=ActivityType.upload,
            title="New media uploaded",
            subtitle=media.file_name,
        )
        db.commit()
        db.refresh(media)
    except HTTPException:
        raise
    except Exception:
        db.rollback()
        logger.exception("Database insert failed for chunked upload %s (owner=%s)", req.filename, current_user.id)
        raise HTTPException(status_code=500, detail="Failed to save media record.")

    # Queue background processing (thumbnails + metadata)
    background_tasks.add_task(
        _generate_thumbnail_background,
        media_id=media.id,
        owner_id=current_user.id,
        relative_path=relative_path,
        media_type=media_type,
    )

    if media_type == MediaType.photo:
        background_tasks.add_task(index_media_background, media.id)

    return MediaRead.from_model(media)


@router.post("/resume", response_model=ChunkedResumeResponse)
def resume_chunked_upload(
    req: ChunkedResumeRequest,
    current_user: User = Depends(require_active_plan),
):
    suffix = Path(req.filename).suffix if req.filename else ".bin"
    relative_path = f"{current_user.id}/{req.media_id}/original{suffix}"

    if _use_r2():
        s3 = _r2_client()
        try:
            res = s3.list_parts(
                Bucket=settings.R2_BUCKET_NAME,
                Key=relative_path,
                UploadId=req.upload_id,
            )
            uploaded_parts = [part["PartNumber"] for part in res.get("Parts", [])]

            part_urls = []
            for i in range(1, req.total_parts + 1):
                url = s3.generate_presigned_url(
                    "upload_part",
                    Params={
                        "Bucket": settings.R2_BUCKET_NAME,
                        "Key": relative_path,
                        "UploadId": req.upload_id,
                        "PartNumber": i,
                    },
                    ExpiresIn=3600,
                )
                part_urls.append(url)
            return ChunkedResumeResponse(part_urls=part_urls, uploaded_parts=uploaded_parts)
        except Exception:
            logger.exception("Failed to resume S3 multipart upload %s", req.upload_id)
            raise HTTPException(status_code=500, detail="Failed to resume storage upload.")
    else:
        try:
            uuid_val = uuid.UUID(req.upload_id)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid upload_id format.")
            
        chunk_dir = _storage_root() / "tmp" / str(uuid_val)
        if not chunk_dir.exists():
            raise HTTPException(status_code=404, detail="Upload session not found.")
        uploaded_parts = []
        for part_file in chunk_dir.glob("*.part"):
            try:
                part_num = int(part_file.stem)
                uploaded_parts.append(part_num)
            except ValueError:
                pass
        return ChunkedResumeResponse(part_urls=None, uploaded_parts=uploaded_parts)


@router.post("/abort")
def abort_chunked_upload(
    req: ChunkedAbortRequest,
    current_user: User = Depends(require_active_plan),
):
    suffix = Path(req.filename).suffix if req.filename else ".bin"
    relative_path = f"{current_user.id}/{req.media_id}/original{suffix}"

    if _use_r2():
        s3 = _r2_client()
        try:
            s3.abort_multipart_upload(
                Bucket=settings.R2_BUCKET_NAME,
                Key=relative_path,
                UploadId=req.upload_id,
            )
        except Exception:
            logger.exception("Failed to abort S3 multipart upload %s", req.upload_id)
            raise HTTPException(status_code=500, detail="Failed to abort storage upload.")
    else:
        try:
            uuid_val = uuid.UUID(req.upload_id)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid upload_id format.")
            
        chunk_dir = _storage_root() / "tmp" / str(uuid_val)
        if chunk_dir.exists():
            shutil.rmtree(chunk_dir, ignore_errors=True)

    return {"status": "ok"}
