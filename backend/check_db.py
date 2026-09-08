import os
import sys
from datetime import datetime, timedelta, timezone

# Add app to path so we can import
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.session import SessionLocal
from app.models.gallery import Media

def check_media():
    db = SessionLocal()
    try:
        print("--- MEDIA DB CHECK ---")
        
        # Calculate cutoffs
        cutoff_aware = datetime.now(timezone.utc) - timedelta(hours=1)
        cutoff_naive = cutoff_aware.replace(tzinfo=None)
        
        print(f"Current Time (UTC aware): {datetime.now(timezone.utc)}")
        print(f"Cutoff Aware (1 hour ago): {cutoff_aware}")
        print(f"Cutoff Naive (1 hour ago): {cutoff_naive}")
        print("----------------------")
        
        # Get latest 5 media
        media_list = db.query(Media).order_by(Media.created_at.desc()).limit(5).all()
        
        for m in media_list:
            created_at = m.created_at
            
            print(f"Media ID: {m.id}")
            print(f"File Name: {m.file_name}")
            print(f"Created At (raw from DB): {created_at} (type: {type(created_at)})")
            
            # Check deletion logic
            is_older_aware = False
            is_older_naive = False
            
            try:
                is_older_aware = created_at <= cutoff_aware
            except Exception as e:
                is_older_aware = f"Error: {e}"
                
            try:
                is_older_naive = created_at <= cutoff_naive
            except Exception as e:
                is_older_naive = f"Error: {e}"
                
            print(f"Would delete (using naive cutoff)? {is_older_naive}")
            print("-")
            
    finally:
        db.close()

if __name__ == "__main__":
    check_media()
