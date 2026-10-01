# Sentorr Codec Lab

Standalone Flutter / MediaKit player for **Windows, macOS, Linux and Android**.
No iOS or web application target. This prototype measures native playback of
complete local files; it does not implement torrent delivery or validate swarm
performance.

## Run

```sh
flutter pub get
flutter run -d windows --release
# On the corresponding host:
flutter run -d macos --release
flutter run -d linux --release
flutter run -d <android-device-id> --release
```

Release/profile builds are required for useful performance comparisons. Windows
needs Visual Studio's Desktop development with C++ workload. macOS needs Xcode.
Linux needs Flutter desktop dependencies and libmpv (`libmpv-dev` on Debian/Ubuntu).
Android needs its SDK, accepted SDK licenses, JDK and a device or emulator.

## Use

- Select a fixture from the queue. Playback loops the current fixture.
- Use the video controls for seek, volume, speed and fullscreen.
- Choose audio/subtitle tracks below the video; the track-switching fixture has
  440 Hz and 880 Hz tones, plain SRT and styled yellow ASS subtitles.
- Load an external subtitle or add your own local media with the toolbar.
- Toggle the stats overlay with the analytics button.
- Change hardware decoding between auto and software using the toolbar menu.
  The **active hardware decoder** in the overlay is the actual mpv result;
  requesting auto does not prove that hardware decoding is active.
- Mark a clip Pass, Video issue, Audio issue or Subtitle issue. These verdicts
  describe your observations, not automatic certification. They last for this
  application session.
- Export a JSON report using the native save dialog (including Android's document picker).
  Reports contain fixture metadata, manual verdicts and the current clip's
  diagnostics/error log. Earlier clips' diagnostics are not recorded.

## Metrics

The overlay samples native mpv properties once per second. Source FPS is nominal
stream FPS; estimated video FPS is mpv's estimate, **not an independently measured
presented-frame rate**. Decoder/output drops and mistimed-frame counters come from
mpv and their availability/behavior depends on the runtime backend. Unsupported
properties show `Unavailable`, never an invented zero. Display refresh is separate
from video FPS. A/V difference is in seconds. UI build/raster timing is Flutter's
rolling 120-frame average; over-budget UI frames use the reported display refresh
rate (60 Hz fallback). UI timing does not measure video frames, and idle UI frames
are not continuously produced. Seeking/looping may affect mpv counters.

## Fixture preparation

The prepared fixtures are bundled as assets and copied to application support
storage at first launch, so every target has an offline queue. This consumes an
additional copy of the fixture bytes on the device. The downloaded baseline clips
are 10 seconds and may contain no audio. Inspect Fixture details for verified streams.

To recreate the corpus, install FFmpeg/ffprobe (with libx264, libx265, DTS, TrueHD)
and curl, then run:

```sh
python tools/prepare_samples.py
```

The script downloads open Big Buck Bunny clips from
[Test Videos](https://test-videos.co.uk/), transcodes controlled variants, and
writes ffprobe stream metadata to `assets/samples.json`. Failed encodes/probes stop
preparation instead of creating a falsely labelled fixture.

Coverage: H.264, HEVC, AV1, VP9, HEVC Main10, H.264 Hi10P, AAC,
FLAC, AC-3 5.1, E-AC-3 5.1, DTS core 5.1, TrueHD 5.1, Opus, MP4,
WebM, MKV, embedded SRT/ASS, multiple audio tracks and synthetic 4K60 Main10.
Generated multichannel audio tests decoding/downmix, not HDMI bitstream passthrough.
The stress clip is synthetic SDR, not a movie-bitrate or HDR benchmark.

The Windows bundled runtime failed the TrueHD fixture in the native smoke check.
Keep this clip in the queue: it exposes a real native-library compatibility gap
that must be addressed before promising TrueHD support in Sentorr.

**Not covered:** Dolby Vision, genuine HDR10 display correctness, Atmos metadata,
DTS-HD MA, Blu-ray PGS fixtures, damaged/incomplete files, DRM, torrent buffering,
thermal/battery measurements. External PGS files can be loaded manually. Add real
representative files before making a final product compatibility decision.

## Attribution

Big Buck Bunny © Blender Foundation, licensed
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).
[Original project](https://peach.blender.org/).
Baseline transcodes from [Test Videos](https://test-videos.co.uk/).
Derived fixtures use locally generated audio/subtitles and FFmpeg transcoding;
their exact sources are recorded in the manifest. Synthetic testsrc2 imagery and
test tones are generated locally.

## Platform verification

See `VALIDATION.md` for actual checks. Platform source generation alone is not a
successful build or runtime test. macOS and Linux builds require corresponding
hosts. A repository CI workflow builds these targets when run on GitHub Actions.

For a repeatable Windows native playback smoke check, run the built executable
with `--smoke-test`. It checks playback progression, decoded video size, audio
decoder presence, seeking and track-selection commands, writes
`sentorr-codec-smoke.json` to Documents, then exits (1 if any fixture failed).
This does not replace visual/audio inspection or a sustained performance benchmark.

## Expected sound and subtitles

Clips 1–4 and 13 contain no audio or subtitle streams. Clips 5–12 use generated
steady tones, not the original movie soundtrack; the tone is expected.
Only clip 12 has embedded subtitles (SRT and styled ASS). Its first subtitle
track is selected on opening; use the subtitle menu to switch tracks or turn
subtitles off. Native libass rendering preserves ASS formatting. Android uses
the bundled Noto Sans font (SIL Open Font License in assets/fonts/LICENSE).
The queue displays these expectations and track menus mark the selected track.
Reports include current audio/subtitle selection and available tracks.
