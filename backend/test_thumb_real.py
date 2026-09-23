import sys, uuid, subprocess
sys.path.append('d:/picgallery/backend')
from app.core.storage import make_video_thumbnail

print(make_video_thumbnail(
    owner_id=uuid.uuid4(),
    media_id=uuid.uuid4(),
    original_relative_path='dd3b4244-36c9-472e-8dc8-c70567f53c11/2612628e-138a-4ed2-b794-ddc24cf820be/original.mp4'
))
