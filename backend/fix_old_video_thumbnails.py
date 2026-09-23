import os
import sys
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.core.database import SessionLocal
from app.models.media import Media
from app.core.config import settings

def fix_thumbnails():
    db = SessionLocal()
    try:
        media_root = Path(settings.MEDIA_STORAGE_DIR)
        videos = db.query(Media).filter(Media.media_type == "video").all()
        fixed_count = 0
        
        print("Looking for videos with missing thumbnails...")
        
        for video in videos:
            if not video.file_path:
                continue
                
            original_path = media_root / video.file_path
            expected_thumb_path = original_path.parent / "thumbnail.jpg"
            
            # Re-generate it if it doesn't exist on disk
            if not expected_thumb_path.exists() and original_path.exists():
                print(f"\nMissing thumbnail for: {video.file_name} (ID: {video.id})")
                
                # Use a simpler scale filter with single quotes to avoid any OS parsing issues
                cmd = [
                    "ffmpeg", "-y", "-i", str(original_path),
                    "-ss", "00:00:00.000",
                    "-vframes", "1",
                    "-vf", "scale='min(480,iw)':-2",
                    "-q:v", "2",
                    str(expected_thumb_path)
                ]
                
                result = subprocess.run(cmd, capture_output=True, text=True)
                
                if result.returncode != 0:
                    print(f"  ❌ FFmpeg failed! Error output:")
                    print(result.stderr[-500:])  # Print last 500 chars of error
                    continue
                    
                if expected_thumb_path.exists():
                    # Update database if needed
                    rel_thumb_path = expected_thumb_path.relative_to(media_root)
                    video.thumbnail_path = str(rel_thumb_path).replace("\\", "/")
                    db.commit()
                    
                    test_url = f"{settings.app_public_url}{settings.MEDIA_URL_PREFIX}/{video.thumbnail_path}"
                    print(f"  ✅ Success! You can view it here to verify:")
                    print(f"  🔗 {test_url}")
                    fixed_count += 1
                else:
                    print("  ❌ FFmpeg succeeded but file was not created?")
                    
        print(f"\nDone! Fixed {fixed_count} video thumbnails.")
    except Exception as e:
        print(f"Fatal error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    fix_thumbnails()
