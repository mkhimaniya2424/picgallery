import asyncio
import uuid
import sys
from app.core.storage import make_video_thumbnail, _storage_root
from pathlib import Path

# Create a dummy video file
dummy_path = _storage_root() / "dummy.mp4"
dummy_path.parent.mkdir(parents=True, exist_ok=True)
if not dummy_path.exists():
    import subprocess
    subprocess.run(["ffmpeg", "-y", "-f", "lavfi", "-i", "testsrc=duration=2:size=1280x720:rate=30", str(dummy_path)])

res = make_video_thumbnail(owner_id=uuid.uuid4(), media_id=uuid.uuid4(), original_relative_path="dummy.mp4")
print("Thumbnail generated at:", res)
