# External torrent performance audit

Measured on 2026-10-02, macOS arm64, release Streaming Lab with local
libtorrent_dart bindings. Actual Pirate Bay API searches: `big buck bunny`,
`sintel`, and `tears of steel`. These Blender open films let the test exercise
real public swarms. Pirate Bay sizes describe the whole torrent, not just the
selected video. Counts below are the API's advertised seeds at search time.

## Results

| Candidate | Torrent size (decimal) | Listed seeds | Metadata | First progressing playback, including metadata | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| Big Buck Bunny 360p H264 | 36.4 MB | 0 | timeout at 60 s | — | No metadata |
| Tears of Steel 720p LAMA | 118.4 MB | 5 | timeout at 60 s | — | Same failure with additional trackers |
| Sintel 1080p CLASSiCALHD | 583.7 MB | 22 | 1.29 s | 19.29 s | Playback and seeks completed |
| Tears of Steel 2160p DON | 13.24 GB | 1 | timeout at 60 s | — | No metadata; 4K decode not tested |
| Tears of Steel 1080p WebM | 571.3 MB | 14 | 3.74 s | 10.21 s | Playback and seeks completed, sustained stalls |

Sintel connected to at most eight peers after metadata. WebM connected to at
most two. A connected peer is not necessarily a seed. Metadata-timeout cases
currently have no peer snapshots: do not interpret their missing observations
as zero peers. Timeout does not prove that a torrent is permanently dead.

| Playback measure | Sintel MKV | Tears of Steel WebM |
| --- | ---: | ---: |
| Video dimensions reported by player | 1920 × 1080 | 1920 × 800 |
| Startup after metadata | 18.01 s | 6.47 s |
| 30 s sustained window | No buffering transitions | Four stalls, totaling 7.90 s of buffering |
| Seek to 50%, then advance 0.5 s | 7.87 s | 7.26 s |
| Seek to 90%, then advance 0.5 s | 13.07 s | 18.20 s |
| Seek backward to 5%, then advance 0.5 s | 0.62 s | 8.47 s |
| Playback pause drift over 2 s | 0 ms | 0 ms |
| Mean sampled process CPU | 24.76% | 26.33% |
| Peak sampled resident memory | 180.95 MiB | 195.30 MiB |
| Selected-file bytes at first progress | 48.27 MB | 0.39 MB |
| Selected-file bytes downloaded by end | 143.04 MB | 33.17 MB |
| HTTP bytes served by end | 36.46 MB | 30.22 MB |

First playback requires the player position to exceed one second. Seek timings
require position to pass the target by 0.5 seconds, not just acknowledgement of
the seek command. These checks establish progression and reported decoded
video dimensions; they do not certify visible quality, audible sound, or
frame drops. `passedChecks` in JSON means functional progression checks passed,
not that the playback experience was smooth.

## Findings and next experiments

1. **Peer discovery is the first reliability concern.** Three initial cases
   could not obtain metadata. Native logs include skipped tracker announces
   on loopback/virtual interfaces, but the successful Sintel run shows public
   discovery works on this host. The five-seed candidate also failed when
   retried with multiple UDP trackers plus an HTTPS tracker. Add metadata-phase
   peer/DHT/tracker telemetry before attributing the failures to network,
   bootstrap, or dead swarms. Test repeated runs and longer metadata budgets.
2. **Startup and seeking need work.** Even the healthier Sintel swarm needed
   19 seconds to start and 13 seconds for its late seek. Compare a byte-budgeted
   read-ahead window with the current five-piece window, separating container
   index probing from continuous playback demands. Five large pieces can mean
   tens of megabytes of urgent downloading. Sintel's 143 MB downloaded versus
   36.5 MB served is evidence to investigate; piece alignment, cancelled seeks,
   read-ahead and player probing all contribute, so this is not a direct
   waste measurement.
3. **A fixed buffer is insufficient evidence of smooth playback.** WebM had
   four stalls despite passing seek/pause checks. Compare demand windows and
   player cache budgets against media bitrate and measured available download
   rate, then measure stall count and duration on repeated runs.
4. **Profile the waiting path.** Metadata-only runs averaged roughly 20% process
   CPU with peak RSS 130–156 MiB. This includes startup/rendering and uses `ps`
   process CPU estimates; it is not a steady-state CPU profiler. Compare an
   idle lab baseline and isolate alert polling, UI repainting, and native
   discovery with a profiler before changing polling frequency.

## Reproduction and limits

Build from this directory with `flutter build macos --release`, then run:

```sh
python3 tool/performance_audit.py
# Optional explicit hashes: performs the additional-tracker comparison.
python3 tool/performance_audit.py 02767050E0BE2FD4DB9A2AD6C12416AC806ED6ED
```

The runner fetches API results live, runs cases sequentially, samples process
CPU/RSS every second, and writes ignored `validation/*.local.json` reports and
logs. It has a 240-second process cap. Interrupted processes may leave their
normal temporary cache behind; completed runs close their sessions and remove
it. No new persistent torrent library or production integration was added.

The first matrix used opentrackr's UDP tracker plus libtorrent discovery. The
WebM and five-seed retry used opentrackr, stealth.si, torrent.eu.org and gbitt's
HTTPS tracker. The runner now uses this broader set by default. Results are
single samples on one network, not a size/seed scaling benchmark: codec,
container, piece size, peer upload capacity and cache history differ. There
was no concurrent-download stress test, prolonged memory-leak test, multi-host
comparison, or successful multi-gigabyte playback. Listed swarm counts can
change immediately.

Checked-in evidence: `validation/performance-summary.json`. Raw local reports
contain per-second engine/system snapshots and native/player events. Static
analysis and all seven existing HTTP transport tests passed after adding the
runner. No engine tuning was applied to produce these numbers.
