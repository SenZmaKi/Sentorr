# Continuity on one Mac

Two **real Sentorr processes**, named Lab MacBook and Lab Phone, share a private
lab directory. Each owns its own settings, watch history, downloads, certificates,
TLS server, loopback media proxy and native MediaKit player. The phone window is
390 × 780; this exercises a phone-sized desktop layout, not Android itself.

From the repository root:

```sh
python3 tool/continuity_lab/run.py
```

The script builds the dedicated development entry point, makes a 60-second video
from the bundled codec sample using local `ffmpeg`, and launches two windows. No
phone, manual pairing or external torrent is needed. The host starts at 0:03.
On Lab Phone's home page, tap **Continue here** above Continue watching. The host
should pause and say **Continued on Lab Phone**, while the phone plays its copy
over pinned HTTPS. Ctrl-C closes both processes.

To use your own video (15 seconds or longer) instead of requiring ffmpeg:

```sh
python3 tool/continuity_lab/run.py --media /absolute/path/to/video.mp4
```

The launcher copies the fixture into the lab sandbox before starting either app;
the original is never a library entry and cannot be deleted through the lab UI.
Every run creates fresh lab data under the app sandbox's `tmp/continuity-lab-*`;
the exact path is printed. Logs and results stay there for inspection. Remove that
printed directory after closing both processes when you no longer need it.
This build replaces the checkout's macOS debug build output; the next normal
`flutter run` builds the regular entry point again.

## Unfinished torrent check

```sh
python3 tool/continuity_lab/run.py --smoke --partial
```

This creates a real local torrent seed and a separately stored partial stream on
Lab MacBook. The default fixture is ten minutes long (about 300 MB) so the player’s
read-ahead cannot finish it before the handoff. No external swarm is involved.
The check asserts that the offered file is still partial, that Lab Phone owns
zero torrents, and that playback proceeds through the source’s verified-byte
server. Source data and the receiver’s playback state remain isolated.

## Automated native check

```sh
python3 tool/continuity_lab/run.py --smoke
```

Both windows remain hidden. The hidden harness keeps the production playback
engine and native Video output mounted from its first frame, bypassing the full
app’s route animations because macOS suppresses hidden-window updates. Interactive
mode uses the full app and PlayerHost. It automatically uses the same continuity offer and transfer notifier as
the button and writes JSON results. It fails if:

- the source is not playing when offered;
- the handoff fails or times out;
- the source does not pause and hold its position;
- the receiver does not decode video with a nonzero width and advance;
- the receiver's position diverges excessively from the source's final position.

The printed `handoffMs` includes preparation and the subsequent playback/paused
verification waits; it is an upper bound, not a measured visual interruption.
The default check uses a completed file; `--partial` uses an unfinished torrent.
Both check speed and volume inheritance and, when the fixture has selectable
tracks, audio/subtitle selection and caption visibility. For the bundled
multitrack fixture:

```sh
python3 tool/continuity_lab/run.py --smoke --media tool/codec_lab/assets/media/tracks_subtitles.mkv
```

To exercise a selected external subtitle rather than an embedded track:

```sh
python3 tool/continuity_lab/run.py --smoke --sidecar
```

The fixture caption is transferred over the authenticated caption endpoint and
imported as transient text on the receiver. No host file path is reused.

These checks do not certify Wi-Fi performance, Android lifecycle behavior, audio
perception or visual smoothness.

## Automated protocol and UI coverage

```sh
flutter test test/sync/continuity_test.dart test/ui/continuity_card_test.dart
flutter test test/sync test/player
```

The continuity suite pairs independent provider containers over real localhost
HTTPS, including lost acknowledgements, competing receivers, failed preparation,
cancellation, source replacement, unpairing, suggestion dismissal/expiry and
file-version/range enforcement. The widget tests cover both themes, a narrow
layout with enlarged text, dismissal, and suppression during local playback.
Existing native buffered-stream tests exercise verified partial-byte serving and
remote-owner retention after the source player releases its owner. The seed is
also shut down in cache-reuse cases, proving those ranges need no new download.
Cancellation coverage checks that discarded player reads release upstream work.

Auto-pairing via the run directory exists **only** in this tool entry point.
Normal app pairing and TLS trust rules are unchanged.


## Device outages

```sh
python3 tool/continuity_lab/run.py --smoke --partial --outage brief
python3 tool/continuity_lab/run.py --smoke --partial --outage permanent
```

The receiving process hosts an independent local torrent seed and tiny tracker;
its app playback engine still owns zero torrents during peer streaming. After
handoff the launcher suspends the host for three seconds or kills it. The receiver
seeks beyond its normal forward buffer, then must advance from that position.
The brief case must retain peer streaming with zero receiver torrents. The
permanent case must open the original torrent in the receiver's app engine and
continue with exactly one torrent, retaining playback controls. No external swarm
or physical phone is needed. `--sidecar` can be combined with either check.
