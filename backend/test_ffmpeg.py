import subprocess
import tempfile
from pathlib import Path

thumb_tmp = Path(tempfile.mktemp(suffix='.jpg'))
result = subprocess.run([
    'ffmpeg', '-y', '-f', 'lavfi', '-i', 'testsrc=duration=2:size=1280x720:rate=30',
    '-frames:v', '1', '-vf', 'scale=min(480\\,iw):-2', str(thumb_tmp)
], capture_output=True)

print("Return code:", result.returncode)
print("Stderr:", result.stderr.decode('utf-8', errors='ignore'))
