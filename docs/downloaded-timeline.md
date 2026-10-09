# Downloaded media timeline

The full and mini players show container-indexed downloaded time intervals.
File offsets are never scaled directly onto the video clock. A complete local,
paired-device or torrent file shows the full track; unsupported partial files
fall back to mpv’s transient demuxer cache ranges.

## Supported layouts

- Ordinary, non-fragmented MP4/M4V/MOV (including legacy MOV without `ftyp`): sample sizes, chunk offsets, decode/composition
  timestamps and sync samples identify video intervals. Required bytes include
  every audio track overlapping the interval, so changing audio cannot make the
  indicator depend on an old selection. Simple rate-one edit lists are supported.
- MKV/WebM with SeekHead, duration, one video track and video Cues: intervals
  between cues require whole byte ranges, including neighboring cue intervals
  for interleaved audio. The final unbounded intervals remain unknown until the
  file is complete. Audio codec delay and seek preroll (including Opus) expand the required
  neighboring cue ranges. Video delay and track timestamp transformations remain
  unsupported and leave partial availability unknown.
- Classic AVI with a complete `idx1` index and one video stream: stream rates,
  sample counts and keyframe flags identify intervals. Adjacent video groups
  and overlapping audio chunks are required conservatively. Both movi-relative
  and absolute index offsets are supported. OpenDML/AVIX, nonzero stream starts,
  initial frames, no-time chunks and inconsistent indexes remain unknown.
- Missing indexes, complex edits, changing MP4 sample descriptions, fragmented
  MP4 and unsupported formats remain unknown. An index is evidence of download
  coverage, not a guarantee of decoder compatibility or stall-free playback.

The worker reads at most 16 MiB of index data, gives indexing 30 seconds, uses
non-urgent sparse demands, and cancels on stream closure. A timed-out or failed
read retries after new verified bytes arrive, with a ten-second backoff and one
active attempt. Unsupported layouts do not retry. Index status changes are
reported in the application log as `Downloaded timeline:`. It never scans the
media payload to discover timestamps. Verified availability changes trigger
projection; large MP4 sample tables are parsed in a separate compute isolate.
Painting receives merged time spans, bounded to 512 display bins
for unusually fragmented maps. Such bins must be completely covered.

## Unsupported-container fallback

While a container index is pending or unsupported, the full and mini tracks use
mpv `demuxer-cache-state.seekable-ranges`. These are buffered timestamp ranges,
not a record of all downloaded bytes; eviction can shrink them. One shared
player controller samples once a second, only during playback when no resolved
container index or complete file is available. Missing or malformed native data
leaves the fallback empty. Seeks, source transitions and disposal invalidate
pending samples; ranges are replaced, never accumulated. A resolved index always
wins, including when its verified coverage is empty. Local or complete files
always show the whole track.

## Bulk native availability

The sibling `../libtorrent_dart` checkout adds `TorrentHandle.getPieces()` and
`torrent_get_pieces`: a copied 0/1 byte array from one native status snapshot.
The app uses this bulk snapshot when supported and retains bounded individual
piece probes for the published 1.1.2 package or an older native binary.

This Mac has gitignored `pubspec_overrides.yaml` files in the app and stream
package pointing to that checkout. Matching macOS ARM64 and Android ARM64 native
binaries were built locally. Path overrides do not compile native C++ by
themselves; follow the dependency's `docs/BUILD.md` when rebuilding.
Other machines use the published dependency until the new API and matching
platform artifacts are released. Do not commit the local override or a path
resolution in the application lockfile.

## Validation

Tests cover sparse metadata reads, tail metadata not producing time spans,
unknown layouts, MP4 audio/video packet coverage, native worker/session
propagation, piece-map updates and light/dark full/mini track rendering.
Synthetic MP4/MKV/MOV/WebM/AVI fixtures under `packages/torrent_stream/test/fixtures/media`
were generated with FFmpeg. The MP4 packet reference was recorded with ffprobe.
Physical Android playback remains a separate check: try MP4 and MKV, seek into
an undownloaded middle region, then verify spans grow only as complete indexed
intervals become available.

Format references: [Matroska timestamps and codec delay](https://www.matroska.org/technical/notes.html),
[Matroska seek preroll](https://www.matroska.org/technical/elements.html),
[Microsoft AVI RIFF layout](https://learn.microsoft.com/en-us/windows/win32/directshow/avi-riff-file-reference).
