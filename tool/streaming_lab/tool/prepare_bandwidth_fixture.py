#!/usr/bin/env python3
"""Generate the 180-second approximately 8.13 Mbps controlled audit video."""
from pathlib import Path
import subprocess
output = Path(__file__).resolve().parents[1] / 'fixtures/network-8mbps.mp4'
output.parent.mkdir(exist_ok=True)
subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
    '-f', 'lavfi', '-i', 'testsrc2=size=1280x720:rate=24',
    '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000',
    '-t', '180', '-c:v', 'libx264', '-preset', 'ultrafast',
    '-b:v', '8M', '-minrate', '8M', '-maxrate', '8M', '-bufsize', '8M',
    '-x264-params', 'nal-hrd=cbr', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart', str(output)], check=True)
print(output)
