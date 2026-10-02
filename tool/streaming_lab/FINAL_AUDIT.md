# Final streaming audit — 2 October 2026

## Decision

Keep **libtorrent → verified pieces → loopback HTTP ranges → MediaKit**. No engine switch is needed. This is a defensible lab baseline, not a guarantee that every torrent will start quickly. WebTorrent source inspection supplied scheduling ideas and exposed a transport comparison confound; it was not benchmarked as a replacement engine.

Use TCP peer connections by default in this lab, ten seconds of playable cache before starting/resuming, a sixty-second forward cache target, a 40 Mbps download cap, 16 MiB demand windows and a 24 MiB owned-piece memory cache. Prioritize only the currently needed piece as time-critical; keep lookahead at ordinary priority. Prepare verified 64 KiB head/tail reads before opening the player. Audio starts muted.

Replace MediaKit's five-second HTTP timeout with **60 seconds**, matching mpv's documented default. This limits a blocked network read, not time spent on the loading screen. Torrent-piece availability has its own 45-second bound, and native disk-read completion has a 15-second bound. Stop cancels outstanding work. At thirty seconds the UI explains that the source is slow; it does not force playback from an empty buffer.

## Method and limits

Tests ran sequentially using the macOS release build and fresh temporary torrent caches. The controlled source is a 180-second 1280×720 H.264/AAC video, approximately 8.13 Mbps, with its MP4 index at the end and **8 MiB torrent pieces**. A local libtorrent seed removes public swarm variability. Downloader caps emulate bandwidth, not WAN latency, packet loss, a router or competition from other applications.

Each playback run waits for position to pass one second, measures sixty seconds of viewing, seeks to 50%, 90%, then 5%, performs three rapid seeks ending at 30%, and checks pause/resume. Seek completion requires progression at the destination, with a 650 ms minimum observation delay. “First progress” includes source preparation and playback startup. The raw `metadataMs` field includes preloading for controlled sessions; `metadataEventMs` in the sanitized summary separates actual metadata readiness.

Viewing progression is the position difference over the viewing window; one-second cache-wait samples provide another freeze signal. These are player telemetry measurements, not human frame-by-frame visual inspection. Public Sintel and WebM runs are observational: their peers and throughput change between runs. They cannot isolate a universal TCP advantage. Windows, Linux, Android, packet loss and high-bitrate 4K were not tested.

## What changed the result

A direct Dart/native read reproduced a stall independently of MediaKit. With the 10 Mbps cap and uTP, piece 0 stopped at **317 of 512 blocks**, 5,193,728 downloaded bytes, while the peer remained unchoked. It stayed incomplete through the 25-second observation. Negotiated peer flags contained the uTP bit. The same probe using TCP verified the first 8 MiB piece in approximately nine seconds. This isolates a transport issue on this host and setup; it does not establish that uTP is generally defective.

The initial uTP-enabled playback pilot was correspondingly poor: one/five-second timeout policies failed to recognize the controlled media, longer waits and a narrower urgent window still timed out, and head/tail preparation at 10 Mbps hit the piece deadline. Changing the HTTP timeout alone could not fix the native stall. These failed experiments remain in the evidence rather than being discarded.

Over TCP, all seven main playback cases and all four refinement cases completed. At 10 Mbps, changing only the HTTP timeout from five to sixty seconds produced essentially identical first progress: **26.57 vs 26.56 seconds**. It reduced startup HTTP requests from **six to three**. The follow-up one-second TCP run was slower at **29.33 seconds**, with **thirteen startup requests** and a **25.91-second middle seek**; shortening the timeout did not improve responsiveness. Narrowing the urgent window gave 24.47 seconds; adding head/tail preparation gave 23.58 seconds. This is a modest controlled startup benefit, not a dramatic discovery. At a bitrate close to the connection cap, downloading two distant 8 MiB pieces and playable content simply takes time.

At 40 Mbps, the follow-up legacy scheduling baseline started in **11.21 seconds**, narrow scheduling without preparation in **12.22 seconds**, and prepared/narrow scheduling in **10.23 seconds**. Source hashing/metadata preparation varied between runs, and these are single controlled repetitions. The smaller policy effects should not be treated as statistically established speed gains. Narrow prioritization is retained to avoid competing urgent requests; preparation bounds and consolidates the initial container reads. The transport reproduction is the strongest finding.

## Main TCP results

All rows use a ten-second ready target and a sixty-second forward-cache target. Times are seconds; viewing columns are video progression / wall-clock window. The controlled 40 Mbps row and public rows use the prepared head/tail plus narrow-urgent policy.

| Source/policy | Cap | First progress | Viewing | Middle seek | Late seek | Backward seek | Rapid seeks |
|---|---:|---:|---:|---:|---:|---:|---:|
| Controlled, five-second HTTP timeout | 10 Mbps | 26.57 | 60.00 / 60 | 13.97 | 34.05 | 1.06 | 0.87 |
| Controlled, sixty-second HTTP timeout | 10 Mbps | 26.56 | 60.00 / 60 | 15.19 | 30.84 | 1.06 | 0.87 |
| Controlled, narrow urgent | 10 Mbps | 24.47 | 59.96 / 60 | 18.07 | 30.58 | 1.06 | 1.07 |
| Controlled, prepared head/tail | 10 Mbps | 23.58 | 60.00 / 60 | 16.03 | 31.47 | 1.06 | 0.88 |
| Controlled, legacy scheduling | 40 Mbps | 11.21 | 60.00 / 60 | 0.86 | 7.47 | 1.16 | 0.88 |
| Controlled, narrow urgent | 40 Mbps | 12.22 | 60.00 / 60 | 0.96 | 7.77 | 1.26 | 0.97 |
| Controlled, prepared head/tail | 40 Mbps | 10.23 | 60.00 / 60 | 1.06 | 6.76 | 1.17 | 0.87 |
| Public Sintel, prepared head/tail | 40 Mbps | 17.84 | 60.00 / 60 | 4.22 | 5.54 | 4.52 | 10.42 |
| Public Sintel, fresh repeat | 40 Mbps | 14.96 | 60.00 / 60 | 6.75 | 13.36 | 5.23 | 11.44 |
| Public WebM, prepared head/tail | 40 Mbps | 29.06 | 60.00 / 60 | 26.55 | 23.56 | 2.28 | 25.40 |

The second fresh-cache Sintel run started faster but took longer to seek: this reinforces that a public swarm is variable, even with unchanged settings.

All completed rows verified volume zero and zero pause-position drift. No TCP case recorded a cache-wait sample during its viewing window; lost viewing time was at most 45 ms, within the sampling/progression precision of this harness. The cap is a ceiling, not a promise that the swarm supplies that rate. The WebM source is usable once buffered in this run, but distant seeks remain poor. Prefer a healthier/lower-bitrate source rather than promising settings can fix insufficient peer delivery.

The earlier [bandwidth audit](TUNING.md) remains relevant: an approximately 8 Mbps video under a 5 Mbps cap lost about 29 seconds of progression in a 90-second viewing window. A larger initial buffer postpones that deficit; it cannot eliminate it indefinitely. Five-second ready buffers were faster on healthy sources, but ten seconds remains the conservative smoothness default.

The rebuilt release app also passed with experimental policy overrides removed: **10.29 seconds** to first progress at 40 Mbps, **60.00 seconds** of progression over the sixty-second viewing window, seeks of **0.96 / 7.57 / 1.06 seconds**, and **0.87 seconds** for rapid seeks. The report confirmed the resolved TCP/preparation/narrow policies, ten-second ready target, sixty-second HTTP timeout and volume zero.

## Readiness and MediaKit

We can prepare data before opening MediaKit, and can control `open(..., play: false)` / `play()` if a manual application gate is needed. The implemented head/tail preparation is an engine-ready signal: those bounded bytes are verified before the URL is handed to the player. It requests 64 KiB at each end, but libtorrent must verify whole pieces, potentially 8 MiB each in this test.

MediaKit/libmpv still has to demux the container to learn tracks, timestamps and byte offsets. A byte count does not prove thirty seconds of playable video, especially with variable bitrate. The player cache gate is therefore the authoritative playable-content readiness check. Head/tail preparation does not replace demuxing, remove all HTTP range requests, or create a reliable time-to-byte index for arbitrary containers. Seeking continues to cancel obsolete requests and let the demuxer request destination bytes.

For a production UI, expose ready buffer (5/10/20/30 seconds), download cap (including unlimited), and a TCP/uTP compatibility option. Keep byte windows, deadline mechanics and HTTP timeouts internal unless diagnostics demonstrate a user need. Reuse an existing torrent session and cached metadata when entering playback; avoid restarting discovery after catalog selection. Session reuse was not measured here.

## Alternatives and stopping point

The next substantial improvement is delivery/source quality: warm metadata/peer discovery, source scoring using actual peer throughput and bitrate, trusted HTTP webseeds where available, or an optional server/debrid cache. The last two introduce external infrastructure and cost; they are separate product decisions. Container-aware index parsing/custom libmpv IO would add substantial complexity and still cannot make peers deliver missing pieces instantly.

Lock the current lab baseline and stop parameter fishing. The remaining slow-start/seek cases should be handled through source selection and clear loading feedback. Retain the experiments as regressions before production integration; do not describe this audit as proof that no further optimization is possible.

## Reproduce and evidence

- [Sanitized final measurements](validation/final-summary.json), generated by `python3 tool/summarize_final.py`.
- `tool/final_audit.py` runs the controlled and public matrix after a release build. Set `STREAMING_FORCE_TCP=1`; case filters use `STREAMING_FINAL_CASES`. Raw local JSON/logs are ignored because they contain paths, source URIs and native network events.
- `tool/acquisition_probe.dart` isolates piece acquisition. Use `STREAMING_FORCE_TCP=0` or `1`, `STREAMING_CONTROLLED_MBPS=10`, `STREAMING_CONTROLLED_PIECE_BYTES=8388608`, `STREAMING_BOOTSTRAP=0`, and `STREAMING_NARROW_URGENT=0` for the transport reproduction.
- Lab policy overrides: `STREAMING_FORCE_TCP=0`, `STREAMING_NARROW_URGENT=0`, `STREAMING_BOOTSTRAP=0` restore each legacy alternative. `STREAMING_NETWORK_TIMEOUT` accepts 1–120 seconds for experiments. TCP mode disables incoming/outgoing peer uTP, while UDP trackers/DHT remain available for external discovery. It can exclude uTP-only peers; preserve the compatibility override and test mixed transport before applying this local workaround universally in production.
- [WebTorrent source comparison](WEBTORRENT.md), pinned to the cloned source revision.

Primary references: [mpv network timeout and cache options](https://mpv.io/manual/stable/), [libtorrent time-critical streaming](https://libtorrent.org/streaming.html). libtorrent already has native streaming-oriented piece deadlines; our HTTP adapter supplies MediaKit's file-like random access.

Validation completed: clean `flutter analyze`, seven passing HTTP/cancellation tests, passing native torrent/HTTP proof, successful macOS release build, eleven TCP matrix/refinement passes, and one passing actual-default release playback check.
