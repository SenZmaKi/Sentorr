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
| State sync and peer libraries | `lib/sync/peers.dart`, `payload.dart`, `shared_library.dart` |
| Streaming a peer's file | `lib/sync/media_proxy.dart`, `PeerFile` in `lib/player/stream/offline_source.dart` |
| Wiring | `lib/sync/service.dart`; started from `lib/app/bootstrap.dart` |
| UI | Settings → Devices (`devices_section.dart`, `pairing_sheet.dart`) |

## What syncs

The whole state is small, so each sync sends all of it. Both sides merge with
functions that give the same result in any order and when repeated.

- **Watch history.** This reuses the backup's `WatchSnapshot.merge`: each item
  keeps its most recently updated record, and removals are remembered for
  90 days so a device that was away can't bring them back.
- **Followed series.** `FollowedSnapshot.merge` (`lib/following/snapshot.dart`)
  keeps the furthest episode reached and the latest `notify` / `notified`
  choice (stamped with `notifyAt` / `notifiedAt`). An unfollow is remembered
  until the series is watched or followed again.
- **Stays on each device:** `autoDownload`, settings and the download library.

A sync is one round trip: `POST /v1/sync` carries this device's state, and the
answer is the other device's merged state. The client then fetches
`GET /v1/library`. Syncs run 10 s after a local change, when a paired device
appears or calls in, when the app resumes, and every 3 minutes. A sync
requested while one is running runs once more afterwards.

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

## Streaming another device's downloads

A device shares its finished downloads whose files are still on disk
(`/v1/library`, and `/v1/media/<imdb id>` with byte ranges).
`offlineSourceFor` looks up a local file first, then a download in progress,
then `peerSourceProvider`, which bootstrap points at a reachable peer. mpv
can't pin a self-signed certificate, so `MediaProxy` serves a loopback URL
with a token and forwards each range request over the pinned connection.
Downloads that aren't finished aren't shared yet.

## Copying instead of downloading

When a download is requested, `PeerCopies.offer` (`lib/sync/copies.dart`)
checks reachable paired devices for the requested items that aren't already
here (`downloadable` in `lib/library/notifier.dart`). Each item comes from the
first device that has it, so one season can draw from several devices.
`CopyOffer` (`copy_offer.dart`) puts what it found into words, such as
"Episodes 1–3 and 5 are already on MacBook".

- **One item** (`ref.download`): the prompt offers Copy, Download instead or
  Cancel.
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
file's length with a byte range. When the file is complete it is renamed and
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
- A movie watchlist.
