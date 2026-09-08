import os
import sys
from datetime import datetime, timedelta, timezone

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app.db.session import SessionLocal
from app.models.gallery import Media
from sqlalchemy import select

def force_delete_all_older_than_1_minute():
    db = SessionLocal()
    try:
        # 1 minute cutoff
        cutoff = datetime.now(timezone.utc) - timedelta(minutes=1)
        old_media = db.execute(select(Media).where(Media.created_at <= cutoff)).scalars().all()
        
        print(f"Found {len(old_media)} images older than 1 minute.")
        for media in old_media:
            print(f"- Deleting {media.file_name} (Uploaded at: {media.created_at})")
            db.delete(media)
        
        db.commit()
        print("Done!")
    finally:
        db.close()

if __name__ == "__main__":
    force_delete_all_older_than_1_minute()
