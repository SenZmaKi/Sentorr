"""Sample process CPU/RSS beside the in-app preview audit (macOS/Linux).

Usage: python3 tool/preview_audit/sample_process.py PID OUTPUT.jsonl [SECONDS]
CPU is derived from cumulative process CPU time, not ps's lifetime average.
"""
import datetime
import json
import pathlib
import subprocess
import sys
import time

if sys.argv[1] == "--wait-for-sentorr":
    deadline = time.monotonic() + 180
    while True:
        matches = subprocess.run(
            ["pgrep", "-f", "^/Users/sen/Dev/Sentorr/build/macos/Build/Products/Profile/Sentorr.app/Contents/MacOS/Sentorr$"],
            capture_output=True, text=True, check=False,
        ).stdout.split()
        if matches:
            process_id = int(matches[0])
            break
        if time.monotonic() > deadline:
            raise SystemExit("Sentorr did not start within 180 seconds")
        time.sleep(0.25)
else:
    process_id = int(sys.argv[1])
output = pathlib.Path(sys.argv[2])
duration = int(sys.argv[3]) if len(sys.argv) > 3 else 900
print(f"Recording PID {process_id} to {output}", flush=True)
started = time.monotonic()
previous = None
with output.open("w", buffering=1) as sink:
    while time.monotonic() - started < duration:
        sample = subprocess.run(
            ["ps", "-p", str(process_id), "-o", "time=,rss="],
            capture_output=True, text=True, check=False,
        ).stdout.split()
        if len(sample) != 2:
            break
        parts = sample[0].split(":")
        cpu = sum(float(value) * 60 ** index for index, value in enumerate(reversed(parts)))
        now = time.monotonic()
        percent = None if previous is None else 100 * (cpu - previous[1]) / (now - previous[0])
        sink.write(json.dumps({
            "at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "pid": process_id,
            "wallSeconds": now - started,
            "cpuTotalSeconds": cpu,
            "intervalCpuPercent": percent,
            "rssBytes": int(sample[1]) * 1024,
        }) + "\n")
        previous = (now, cpu)
        time.sleep(1)
