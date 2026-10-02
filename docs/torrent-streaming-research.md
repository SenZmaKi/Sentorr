# Torrent streaming engine research

Research date: 2026-10-02. This is an architecture investigation, not an implemented or playback-tested engine.

## Recommendation

Build a seekable torrent-backed byte source and expose it to MediaKit through a loopback HTTP server. Keep the piece scheduler independent of HTTP so a native mpv stream adapter can replace the transport later if measurements justify it.

Libtorrent already supports streaming-oriented piece scheduling. We do not need to invent a torrent protocol or download the complete movie before playback. We do need to implement the bridge that waits for verified bytes, schedules missing pieces, and supplies the player with normal seekable media. All playback still involves downloading bytes; the distinction is whether useful bytes arrive in time to watch while the remainder is incomplete.

## Verified capabilities and current gaps

Libtorrent's [streaming documentation](https://libtorrent.org/streaming.html) distinguishes sequential downloading from time-critical downloading. Sequential ordering can leave an early piece on a slow peer while later pieces arrive from faster peers. Piece deadlines actively prioritize urgent work across peer queues. Deadlines are best-effort, not a guarantee that an unhealthy swarm can sustain playback.

The sibling checkout vendors **libtorrent 2.0.11**, while the current official documentation labels itself 2.1.0. Confirmed controls below exist in the vendored headers too; newer documented APIs must not be assumed available. See [version.hpp](../../libtorrent_dart/thirdparty/libtorrent/include/libtorrent/version.hpp) and [torrent_handle.hpp](../../libtorrent_dart/thirdparty/libtorrent/include/libtorrent/torrent_handle.hpp).

The existing [Dart torrent handle](../../libtorrent_dart/lib/src/high_level/torrent_handle.dart) already exposes file and piece priorities, piece deadlines and resets, `havePiece`, `readPiece`, file sizes and torrent-relative file offsets, and pause/resume. It does **not** yet provide a complete byte-reader:

- `readPiece` returns void. Native completion arrives through `read_piece_alert`, but [AlertInfo](../../libtorrent_dart/lib/src/high_level/models.dart) and [the session alert marshaling](../../libtorrent_dart/lib/src/high_level/session.dart) expose no piece index, byte buffer, byte count or read error payload.
- Piece length and the actual size of each piece are not exposed by the inspected high-level API. Add a structured torrent layout or byte-to-piece mapping API, including v2/hybrid and short boundary pieces.
- Typed piece completion and metadata/error events would avoid parsing human-readable alert messages and reduce polling.
- **Concrete alert-loss blocker:** the C `session_pop_alert`, `session_pop_alert_info` and `session_pop_alert_typed` functions call native `pop_alerts` for a batch but serialize only `alerts.front()`. Remaining events are discarded. Repeated Dart pops cannot recover them. Replace this with a complete copied batch or an owned pending queue before depending on asynchronous piece-read completion; see [library.cpp](../../libtorrent_dart/src/c/library.cpp).

The official [torrent handle reference](https://libtorrent.org/reference-Torrent_Handle.html#read_piece()) defines `read_piece` as asynchronous and completion as a read alert. The [vendored alert definitions](../../libtorrent_dart/thirdparty/libtorrent/include/libtorrent/alert_types.hpp) explicitly warn that `piece_finished_alert` can arrive before disk flush, with `have_piece` still false. Prefer a native read-buffer path for the durable interface: copy the alert bytes before native ownership expires, propagate read errors, and slice the returned bytes to the requested file range. An externally read disk path needs explicit availability gating and verified disk visibility; file length or a piece-finished event alone is insufficient.

Sentorr's root [pubspec](../pubspec.yaml) currently contains neither MediaKit nor libtorrent. [Codec lab](../tool/codec_lab/README.md) and its [validation notes](../tool/codec_lab/VALIDATION.md) establish local-file playback experiments, not torrent streaming or production runtime compatibility.

The previous Electron implementation already uses the same broad bridge: WebTorrent `createServer`, localhost stream URLs, metadata discovery, selected files and a bounded retained-file queue. See [server.ts](../Electron/src/backend/torrent/server/server.ts) and [manager.ts](../Electron/src/backend/torrent/server/manager.ts). Flutter must own cancellation, scheduling and lifecycle rather than copying IPC/store boundaries.

## Approaches

| Approach | Advantages | Limitations | Assessment |
| --- | --- | --- | --- |
| Play the partially downloaded file directly | Minimal transport code | Player sees holes/EOF rather than a reliable wait-for-bytes contract; seeks need scheduling; disk visibility must be proven | Useful experiment, weak production foundation |
| Torrent byte source behind local HTTP ranges | Existing MediaKit URL path, observable requests, straightforward transport tests, independent engine | HTTP correctness, request cancellation, caching and backpressure need care | Recommended first implementation |
| Native mpv custom stream callbacks | Direct read/seek/size/cancel contract, avoids HTTP framing | Native threading and resource lifetime work, MediaKit integration changes, API marked unstable | Later alternative if justified |
| Remux/transcode into HLS or another streaming format | Can address selected decoder/container constraints | Extra CPU, startup, lifecycle and time-to-source mapping; does not remove torrent scheduling | Separate feature for demonstrated compatibility needs |

MediaKit's [official repository documentation](https://github.com/media-kit/media-kit) supports URL media, seek and pause controls, and position, buffering and demuxer-buffer events. Keep MediaKit responsible for decoding and time-based seeking. Its buffered position is not the same as torrent piece availability.

The native alternative is real: [mpv stream_cb.h](https://github.com/mpv-player/mpv/blob/master/include/mpv/stream_cb.h) allows custom open/read/seek/size/close and cancellation callbacks. Reads may block awaiting data; zero means EOF. Callbacks cannot call back into the same libmpv instance because that can deadlock. This route requires a native thread-safe bridge, not a casual synchronous Dart callback around an asynchronous torrent read.

## HTTP bridge behavior

The server represents the selected file's complete logical length even while only some pieces are downloaded. Implement `HEAD`, full `GET`, and single byte ranges, including open-ended and suffix ranges. Return `206` with correct `Content-Range` for accepted ranges, `416` for unsatisfiable ranges, and accurate lengths; define handling for unsupported multiple ranges. Follow [RFC 9110 range semantics](https://www.rfc-editor.org/rfc/rfc9110.html#name-range-requests).

For each request, translate file byte offsets into the torrent layout, register demand, wait for complete verified pieces, and stream bounded chunks. Missing data should produce a cancellable wait, never fabricated zeros or false EOF. If a transfer fails after headers were sent, close the response and surface the engine failure rather than pretending its advertised length was delivered. Bind to loopback with an opaque session URL and retire it on session disposal.

**Proposed scheduling policy:** immediate demanded pieces get earliest deadlines; a bounded lookahead window gets progressively later deadlines; the rest of the selected file gets low background priority or no priority according to cache policy. Other files stay deselected, allowing required shared boundary pieces. Set file priorities first because libtorrent file-priority changes reset piece priorities; apply piece scheduling after those changes complete. Recompute deadlines as consumers advance and remove deadlines when no active demand needs them.

Do not declare an entire `bytes=0-` response urgent: the player may request through EOF while consuming slowly. Advance the scheduling window with actual consumption and HTTP backpressure. Allow several simultaneous demand windows: container probes, read-ahead and seeks may compete. Cancellation removes only that request's contribution; it must not clear deadlines still needed by another consumer. A seek changes the active playback demand, while obsolete requests and their waiters are retired. Measure the player's real request patterns before picking window sizes.

## Seeking, metadata and pause

A seek is a player time request that becomes demuxer byte requests. The engine prioritizes those bytes, then the player resumes after buffering. Avoid `position / duration * fileSize` as an exact mapping: variable bitrate, indexes, keyframes and interleaved tracks make it unreliable. No container parser is needed in the first engine if we follow the demuxer's actual requests.

Startup is not always just the file beginning. FFmpeg's [MP4 format documentation](https://ffmpeg.org/ffmpeg-formats.html#mov_002c-mp4_002c-ismv) explains the `moov` index and `faststart` relocation. An MP4 with an index at the end may require tail bytes before decoding; fetching only an opening buffer can stall startup. Let range probes drive demand initially; investigate bounded head/tail prefetch only with evidence.

Treat player pause and torrent pause as different controls. **Proposed default:** pause playback immediately, continue fetching only until a bounded cache target, then reduce background fetching; resume with available verified data. Full torrent pause disconnects transfer activity and can worsen resume latency. Explicit bandwidth/download pause can remain a separate policy. The [mpv manual](https://mpv.io/manual/stable/#options-cache-pause) documents cache-related buffering and rebuffering after seeks; tune player cache with the torrent window rather than creating two unbounded buffers.

## Clean ownership

Proposed boundaries fit Sentorr's feature layout:

- `TorrentSession`: metadata, torrent handles, native lifecycle, one alert pump and typed events; execute blocking native queries away from Flutter's UI isolate.
- `TorrentByteSource`: seekable file descriptor and cancellable verified range reads; owns layout mapping and bounded piece buffers.
- `PieceDemandScheduler`: combines consumers, deadlines, lookahead and pause/cache policy; independent of player and transport.
- `LocalMediaServer`: HTTP semantics and request lifecycle; consumes the byte source.
- `StreamingPlaybackSession`: links a selected file and local media URL to MediaKit, exposes readiness/buffering/errors and disposes all resources together.

Keep playback position, demuxer buffer and verified torrent ranges distinct in state. Aggregate download percentage cannot prove readiness at the current seek target. Cleanup must stop new requests, cancel waits, stop playback before deleting backing storage, drain/remove the torrent, and then release native resources.

## Bounded first proof

1. Fix the native alert batch loss, then extend libtorrent_dart with layout metadata and typed copied read-piece payloads. Test byte-exact reads, native error propagation and alert lifetime against a locally seeded deterministic torrent.
2. Prove the range server independently: cross-piece/file boundaries, short final pieces, suffix ranges, cancellation and concurrent requests. Confirm missing bytes block and completed reads match the source.
3. Add a desktop streaming lab using MediaKit and a controlled local seed. Demonstrate playback before completion, forward/backward seeks into absent regions, rapid repeated seeks, pause/resume, stalled/swarm-lost recovery and disposal. Cover faststart and tail-index MP4, MKV, and multi-file torrents.
4. Record startup time, seek latency, rebuffer events, wasted post-seek downloads, memory/disk use and native/player logs. Then choose cache/window defaults and integrate the application UI. Extend verification to each shipped platform and actual bundled libmpv runtime.

A local Dart path dependency selects the local wrapper source, but native C changes require rebuilding the correct platform/architecture artifact. Check [libtorrent_dart BUILD.md](../../libtorrent_dart/docs/BUILD.md) and its native-assets hook; it can otherwise use/download a release binary with the old ABI. Publish the wrapper and matching native artifacts together after the proof.

No integration, torrent playback test, browser inspection or codec compatibility claim was performed for this research.
