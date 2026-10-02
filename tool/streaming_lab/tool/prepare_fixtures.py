#!/usr/bin/env python3
"""Generate controlled media locally; no external download or copyrighted fixture."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1] / 'fixtures'
root.mkdir(exist_ok=True)
base = root / 'tail-index.mp4'
subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
    '-f', 'lavfi', '-i', 'testsrc2=size=640x360:rate=24',
    '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000',
    '-t', '90', '-c:v', 'libx264', '-preset', 'fast', '-b:v', '1400k',
    '-g', '48', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '96k', str(base)], check=True)
for name, extra in [('faststart.mp4', ['-movflags', '+faststart']), ('sample.mkv', [])]:
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y',
        '-i', str(base), '-c', 'copy', *extra, str(root / name)], check=True)
print(root)
