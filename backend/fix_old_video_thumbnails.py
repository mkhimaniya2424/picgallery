import os
import sys
import subprocess
import uuid
from pathlib import Path

# Add the backend root to python path so we can import app
sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.core.database import SessionLocal
from app.models.media import Media

THUMBNAIL_MAX_DIMENSION = 480

def generate_thumbnail(original_file: Path, thumb_file: Path) -> bool:
    try:
        result = subprocess.run([
            "ffmpeg", "-y", "-i", str(original_file),
            "-ss", "00:00:00.000",
            "-vframes", "1",
            "-vf", f"scale=min({THUMBNAIL_MAX_DIMENSION}\\,iw):-2",
            "-q:v", "2",
            str(thumb_file)
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"FFmpeg error: {result.stderr}")
            return False
            
        return thumb_file.exists()
    except FileNotFoundError:
        print("FFmpeg not found! Please ensure ffmpeg is installed.")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False

def fix_thumbnails():
    db = SessionLocal()
    try:
        from app.core.config import settings
        media_root = Path(settings.MEDIA_STORAGE_DIR)
        
        print("Looking for videos with missing thumbnails...")
        # Find all videos
        videos = db.query(Media).filter(Media.media_type == "video").all()
        fixed_count = 0
        
        for video in videos:
            if not video.file_path:
                continue
                
            original_path = media_root / video.file_path
            
            # If thumbnail is missing or thumbnail_path is not in DB
            needs_thumbnail = False
            expected_thumb_path = original_path.parent / "thumbnail.jpg"
            
            if not video.thumbnail_path:
                needs_thumbnail = True
            else:
                current_thumb_path = media_root / video.thumbnail_path
                if not current_thumb_path.exists():
                    needs_thumbnail = True
                    expected_thumb_path = current_thumb_path
            
            if needs_thumbnail and original_path.exists():
                print(f"Generating thumbnail for {video.file_name} ({video.id})...")
                
                success = generate_thumbnail(original_path, expected_thumb_path)
                
                if success:
                    # Update database relative path
                    rel_thumb_path = expected_thumb_path.relative_to(media_root)
                    video.thumbnail_path = str(rel_thumb_path).replace("\\", "/")
                    db.commit()
                    print(f"  -> Successfully created thumbnail!")
                    fixed_count += 1
                else:
                    print(f"  -> Failed to create thumbnail.")
                    
        print(f"\nDone! Successfully fixed {fixed_count} video thumbnails.")
    finally:
        db.close()

if __name__ == "__main__":
    fix_thumbnails()
