# macOS performance audit

`audit.dart` runs production bootstrap and screens without revealing/focusing the
window. It uses an independent data root, production search/title providers and
download queue, and a real loopback torrent served to MediaKit through the
production engine and adapter. Playback uses a dedicated video widget rather
than the complete player page. `seed.dart` runs in a separate process, so its
hashing, disk reads and CPU are excluded from app measurements.

Use a fresh directory inside the app's sandbox container. An arbitrary `/tmp`
root fails the app's sandbox access checks. Existing downloads and caches change
the workload; `run.py` rejects reuse of a root with a `data` directory.

From the repository root:

```sh
export SENTORR_AUDIT_RUN="$HOME/Library/Containers/com.sentorr.sentorr/Data/tmp/perf-$(date +%s)"
mkdir -p "$SENTORR_AUDIT_RUN/seed"
ffmpeg -hide_banner -loglevel error -stream_loop -1 \
  -i tool/codec_lab/assets/media/bbb_h264.mp4 -t 120 -c copy \
  "$SENTORR_AUDIT_RUN/seed/fixture.mp4"
# In a separate terminal, keep running until the audit finishes:
dart run tool/performance/seed.dart \
  "$SENTORR_AUDIT_RUN/seed/fixture.mp4" "$SENTORR_AUDIT_RUN/seed.json"
# In the first terminal:
flutter build macos --profile -t tool/performance/audit.dart
python3 tool/performance/run.py --root "$SENTORR_AUDIT_RUN"
python3 tool/performance/summarize.py "$SENTORR_AUDIT_RUN"
```

When other work is changing/building the project, build an isolated checkout
instead and pass `run.py --app /absolute/path/to/Sentorr.app/Contents/MacOS/Sentorr`.
Keep the sibling libtorrent dependency available. Stop the seed process after
completion. No browser tools are involved.

The complete workload takes about five minutes. `SENTORR_AUDIT_STATIC=1` runs
only home, home with disabled/resumed tickers, and a blank UI. The complete run also
includes that animation comparison after playback. Ticker enablement changes through a stable widget tree, preserving the mounted
home page. The static workload also resumes tickers to check reversibility.

Outputs:

- `app.log`: per-second app RSS, decoded image cache, torrent traffic and piece
  cache, plus workload events, decoder identity and frame-drop count.
- `os.jsonl`: process CPU time and RSS sampled once per second. CPU derives from
  deltas of cumulative CPU time, with **100% meaning one fully busy core**.
- `heap.jsonl`: VM-service memory usage every five seconds. Isolates sharing an
  isolate group may report the same heap; do not sum their values.
- `*.vmmap.txt`: physical footprint and region categories at selected phase
  beginnings. These are snapshots, not phase averages; graphics, compressed
  memory and RSS have different accounting.
- `*.sample.txt`: three-second native thread stack samples. Includes waiting
  threads, so sample counts are not automatically CPU percentages.
- `summary.json`, `host.txt`: phase CPU/RSS summaries and host details.

Limitations: hidden rendering differs from a foreground window; this is not a
visible scroll-jank, GPU-time, battery, real internet swarm, or long-running leak
benchmark. Live IMDb data and current machine pressure affect results. The
loopback seed's per-torrent upload limit targets 1 MiB/s, but measure the actual
rates in telemetry rather than assuming the limit. App CPU excludes the seed,
profiling tools, WindowServer and other processes; profiling still adds overhead.
Shutdown is bounded to 15 seconds; exit code 2 reports a shutdown timeout
after the workload completes. The final app should be rebuilt with its normal `lib/main.dart` entrypoint before
using the Profile bundle for ordinary application use.
