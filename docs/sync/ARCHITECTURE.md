# Device sync and streaming

Status: agreed with the owner on 4 October 2026 and implemented for the local
network (phases 1–3 below). Cloud backup is separate work in `lib/backup/`.
Update this file when a decision changes.

## Shape

Local-first, with no Sentorr server. Devices pair once, find each other over
mDNS (`_sentorr._tcp`), and talk HTTPS directly. There are no accounts, and
nobody else holds anyone's history.

| Piece | Code |
| --- | --- |
| Identity, pinned TLS certificates | `lib/sync/identity.dart` |
| Paired devices, saved in `state/devices.json` | `lib/sync/devices.dart`, `repository.dart`, `models.dart` |
| Numeric-comparison pairing | `lib/sync/pairing.dart`, `pairing_code.dart` |
| Server, client, mDNS | `lib/sync/server.dart`, `client.dart`, `discovery.dart` |
| State sync and peer libraries | `lib/sync/peers.dart`, `payload.dart`, `shared_library.dart`, `elsewhere.dart` |
| Other devices' downloads in the UI | `elsewhere_button.dart` in `lib/ui/components/`; `elsewhere_section.dart`, `elsewhere_row.dart` in `lib/ui/pages/downloads/` |
| Streaming a peer's file | `lib/sync/media_proxy.dart`, `PeerFile` in `lib/player/stream/offline_source.dart` |
| Wiring | `lib/sync/service.dart`; started from `lib/app/bootstrap.dart` |
| UI | Settings → Devices (`devices_section.dart`, `pairing_sheet.dart`) |

## What syncs

The whole state is small, so each sync sends all of it. Both sides merge with
functions that give the same result in any order and when repeated. Upgraded
records use Lamport revisions (`lib/shared/state_clock.dart`) rather than device
wall clocks to order changes. Every local change advances past all observed
revisions; concurrent ties have deterministic content winners, with a removal
winning over a record at the same revision. The logical high-water mark is persisted even when records are pruned. Wall timestamps remain for display
and the 90-day removal retention policy. Legacy records without revisions retain
their timestamp ordering until updated.

- **Watch history.** This reuses the backup's `WatchSnapshot.merge`: each item
  keeps its latest revision, and removals are remembered for
  90 days so a device that was away can't bring them back.
- **Followed series.** `FollowedSnapshot.merge` (`lib/following/snapshot.dart`)
  keeps the furthest episode reached and the latest `notify` / `notified`
  choice (separate `notifyRevision` / `notifiedRevision` counters). An unfollow is remembered
  for 90 days, or until the series is watched or followed again. Merged records
  retain flattened, deduplicated original contributions so a removal received
  later can discard obsolete progress regardless of three-device merge order.
  A local playback update acknowledges the merged progress as a new event.
- **Stays on each device:** `autoDownload`, settings and the download library.

A sync is one round trip: `POST /v1/sync` carries this device's state and its
library (below), and the answer is the other device's merged state and
library, so both sides learn what the other holds from one call. A device
whose answer has no library is asked with `GET /v1/library`. Syncs run 10 s
after a watch or follow change, 2 s after a download is added, removed,
started, paused or finished (`sharedLibraryShapeProvider`, which ignores bytes
arriving), when a paired device appears or calls in, when the app resumes, and
every 3 minutes. A sync requested while one is running runs once more
afterwards. Pending deadlines keep the earliest request. Unpairing invalidates
in-flight request generations; late results cannot merge or republish peer state.
Library polls are serialized per peer and invalidated by newer syncs. Discovery
loss marks a peer offline; a changed/reappearing address triggers a fresh sync.

## Pairing

Pairing uses numeric comparison, as in Bluetooth, so neither device needs a
camera or a keyboard.

1. The host opens pairing for 5 minutes and announces `pair=1`.
2. The joiner sends its id, name, certificate and `sha256(nonce)`.
3. The host answers with its own id, name, certificate and nonce. The joiner
   checks that the certificate in the answer is the one TLS presented.
4. The joiner reveals its nonce, and the host checks it against the commitment.
5. Both devices show `code = sha256(fpJoiner, fpHost, nonceJ, nonceH) mod 10⁶`,
   and both viewers confirm. The joiner sends its decision, and the host's
   answer carries the host's.

The joiner commits to its nonce before seeing the host's, so someone in the
middle gets a single 1-in-a-million guess per attempt. Pairing closes after
one attempt, a mismatch, or the timeout. If discovery is blocked, the host
shows its address and the joiner can type it in.

## Trust and transport

- Each device has a self-signed P-256 certificate. Dart's TLS rejects Ed25519
  certificates. Validity ends before 2050, because basic_utils writes dates
  as UTCTime, and a later date reads as already expired.
- The client pins the peer's SHA-256 certificate fingerprint and presents its
  own certificate. The server only completes handshakes with certificates it
  was told to trust, and still checks on every request that the device is
  paired. Unpairing removes that check, which is why unpairing a device
  immediately cuts it off.
- The server listens on port 47615 when it's free (otherwise any port) and on
  every interface. Callers send `x-sentorr-port`, so the host learns where to
  call back.

## Compatibility before exchange

Discovery and installation identity are independent. Stable and nightly use
separate local state, downloads, credentials and pairing identities, but announce the same `_sentorr._tcp` service. Discovery includes
the channel, and nightly names are labelled. Pairing remains explicit.

Before every sync, library poll, or media GET/HEAD, `PeerClient` sends a
metadata-only `GET /v1/hello` over the existing pinned, mutually authenticated
TLS connection. Both sides declare `application: sentorr`, validation format 1,
protocol 1, channel and the versions of watch (2), following (1), lists (1),
library (1) and media (1). Channel is informational; all required format
versions must match. App release numbers are not used to infer compatibility.

Every data request repeats the declaration in `x-sentorr-compatibility`.
The server validates it before reading the request body or calling any state,
library or media handler. The client rechecks the response declaration before
using received records or forwarding file bytes. The probe runs each time so
restarting a peer into an older or incompatible build cannot reuse stale
compatibility. This adds one small HTTP round trip per operation, including
media range requests, over reused connections.

Missing, malformed or mismatched declarations receive HTTP 426. Legacy builds
without `/v1/hello` are refused before sending state or requesting media. They
remain discoverable/pairable, but participating devices must update. Settings
shows an incompatible-build explanation rather than treating the failure as a
normal offline device. Unknown declarations are never assumed compatible.

A complete sync exchange is decoded and its top-level structure validated before
merging any records. Existing per-record recovery remains in the codecs. Schema
or merge-semantics changes must bump the affected version in
`lib/sync/compatibility.dart`; a new required format must be declared too. This
contract applies to stable-to-stable exchanges as well as cross-channel ones.
Explicit sync still propagates changes and removals across paired installations;
local separation does not undo intentional synchronization.

## Streaming another device's downloads

A device shares its finished downloads whose files are still on disk
(`/v1/library`, and `/v1/media/<imdb id>` with byte ranges).
`offlineSourceFor` looks up a local file first, then a download in progress,
then `peerSourceProvider`, which bootstrap points at a reachable peer. When
Play finds only a peer's copy, the launch dialog asks before using it: it
plays once the auto action countdown (`TorrentSettings.autoActionDelay`) runs
out, and Stream instead searches for a torrent. The player's own lookup, e.g.
for the next episode, uses a peer's copy without asking. Picking such an
episode in the player's episodes panel goes through the launch instead of
jumping within the queue, so it asks too. mpv
can't pin a self-signed certificate, so `MediaProxy` serves a loopback URL
with a token and forwards each range request over the pinned connection.
Downloads that aren't finished can't be streamed from yet, but they are
listed (below).

## Seeing other devices' downloads

A device's library (`PeerLibrary` in `payload.dart`, built by
`sharedLibrary`) holds its finished files (`PeerMedia`) and its downloads and
copies under way (`PeerDownload`: queued, downloading, paused or copying,
with progress and size). While a reachable device has downloads under way,
its library is fetched every 5 s so their progress moves here too.

`elsewhereProvider` (`lib/sync/elsewhere.dart`) lists each reachable device's
items, and `elsewhereOfProvider` picks one item's best copy: the first device
that has it finished, which is the one playback would use, else the furthest
along. The UI only uses it where this device has nothing of that item, so a
local download always wins.

- **Download buttons** (episode rows, the player's episodes panel, previews,
  the title hero) become `ElsewhereButton`: "On MacBook" with a devices glyph
  when it's finished there, or a quieter ring and "On MacBook 42%" while it
  downloads there. Episode rows also name the device in their facts ("On
  MacBook", "On MacBook · 42%"), so touch screens see it without a tooltip.
  The menu offers Play from MacBook, Copy here from MacBook and Download
  instead, or Show in Downloads and Download here too. Play from MacBook opens
  the player straight away: the viewer chose the copy, so the launch doesn't
  offer streaming instead.
- **The Downloads page** ends each tab with a section per device for what
  this device lacks: downloads under way on Ongoing, finished ones on
  Complete, each row playing on tap and offering a copy or a download here.
  Tab counts and the tab the page opens on still follow this device alone.

## Copying instead of downloading

When a download is requested, `PeerCopies.offer` (`lib/sync/copies.dart`)
checks reachable paired devices for the requested items that aren't already
here (`downloadable` in `lib/library/notifier.dart`). Each item comes from the
first device that has it, so one season can draw from several devices.
`CopyOffer` (`copy_offer.dart`) puts what it found into words, such as
"Episodes 1–3 and 5 are already on MacBook".

The prompt copies once the auto action countdown runs out; any touch or key
stops it.

- **One item** (`ref.download`, e.g. retrying a failed download): the prompt
  offers Copy, Download instead or Cancel. An item's download button already
  names the device, so it offers the copy from its menu instead.
- **A season** (`ref.downloadSeason`): the prompt offers Copy and download
  the rest, Download all or Cancel. The prompt also serves as the season's
  confirmation. Copies start before the season review lists its episodes, so
  episodes being copied are never searched for. Episodes from other seasons
  are never offered.
- **Automatic downloads** copy without asking, through the planner's
  `peerCopyProvider` hook, since there's nobody to ask.

Copies run one at a time and show as `OfflineProgress.copying`, with the
source device's name, wherever downloads show (`copyingProvider`). A copy
writes `<path>.part` in the normal download layout and resumes from that
file's length only when its `.part.json` metadata matches the source device,
file version, size, torrent hash and file index. The source publishes a file
version based on path and filesystem metadata and enforces it using `If-Match`;
the copier verifies ETag and Content-Range, then rechecks the source version
with HEAD before publishing the completed file. Changed sources or unversioned old
partials restart; a changed file offer is rejected. Old devices without file
versions must be updated before copying. When the file is complete it is renamed and
joins the library as a normal entry (`downloadId: copy:<device>:<item>`, with
the peer's release and file index). Deleting it is the same as deleting any
download. Cancelling a copy, or cancelling its season, deletes the partial
file. A failure keeps the partial file so the next attempt resumes it.

## Platforms

- macOS declares `NSBonjourServices` and `NSLocalNetworkUsageDescription`. The
  sandbox already had the network server and client entitlements.
- On Android, bonsoir adds the multicast permission and manages its own lock.
- Discovery failures are logged, never thrown, and devices stay reachable by
  address.

## Later

- Remote sync and streaming away from the home network: an encrypted copy of
  the state in a folder the viewer picks, and streaming over Tailscale or a
  typed-in address.
- Streaming a peer's download while it's still in progress.
- Pausing or cancelling another device's download from this one.
- A movie watchlist.

## Drive state sync and compatibility

Drive uses immutable `sentorr-backup.json` snapshots in appDataFolder. Downloads
list every matching file (including all pages, duplicate files and the former
`sentorr-nightly-backup.json` name), validate all snapshots, then merge their
contents. Stable and nightly share these snapshots when signed into the same
Google account and configured with the same Drive OAuth application. Legacy
nightly names and multiple snapshots trigger consolidation even when the merged
data is unchanged. An upload publishes its merged snapshot first and removes
only the snapshot ids that writer read. Concurrent publishers retain each other's
new files; later publication compacts the observed files. Failed cleanup is safe
and retried through a later publication. A read that races compaction relists the
files rather than treating missing snapshots as an empty backup.

Background/resume sync pushes dirty state even after a recent successful sync,
and requests/changes during an upload queue a follow-up pass.

Backup bundles emit envelope version 3, declaring the shared watch (2), following
(1) and lists (1) formats from `lib/shared/state_formats.dart`. Supported version
1/2 bundles and history-only exports remain readable. Watch-history exports still
emit version 2. Format or merge-rule changes must bump their declared versions;
adding a new required domain must also bump the backup envelope version.

Drive reads validate all declared formats, containers, records and removal
records before exposing any merged data. Unlike recovery-oriented file imports,
Drive refuses snapshots with records that its codecs would silently skip. An
unsupported or malformed snapshot stops the whole sync: no local merges,
uploads or remote deletion. A failed read invalidates prior upload eligibility.
Older builds that cannot read envelope version 3 refuse it instead of discarding
its metadata; update those participating devices. Different app releases and
channels with supported formats interoperate. Local autoDownload preferences
remain per-device, including within contribution metadata.

The new Drive implementation uses documented [file creation/upload](https://developers.google.com/workspace/drive/api/guides/manage-uploads)
and file deletion rather than relying on an unchecked conditional PATCH.
Concurrency and transport are tested with adapters and loopback devices; live
Google Drive and separate physical-device validation remain outstanding.
