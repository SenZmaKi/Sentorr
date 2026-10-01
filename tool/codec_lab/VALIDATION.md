# Verification

- Fixture generation: 13 files, approximately 100 MB; ffprobe stream metadata
  captured for every clip in `assets/samples.json`.
- Static analysis: final source passed with no issues.
- Windows release build: successful on this Windows 11 x64 host.
- Windows native smoke check: 12/13 passed playback progression, video decoder
  output dimensions, expected audio decoder presence and seeking.
- Track-switching fixture: two audio and two subtitle tracks discovered;
  audio and subtitle selection commands accepted. Visual subtitle styling and
  audible switching still require human inspection.
- **TrueHD failed:** bundled runtime reported `Failed to initialize a decoder
  for codec 'truehd'.` Video continued; this is retained as a compatibility finding.
- H.264, HEVC, HEVC Main10, AV1, VP9 and the synthetic 4K60 fixture reported
  `d3d11va-copy` hardware decoding on this host. H.264 Hi10P reported software
  decoding (`hwdec-current=no`). This is hardware-specific, not a platform guarantee.
- Startup output-drop counts of 0–2 were observed in the brief smoke check.
  These samples are too short to establish sustained playback performance.
- The smoke report is saved in `validation/windows-smoke.json`.
- Android release APK: built successfully on this host; no Android runtime test
  was possible because no device/emulator was connected. Build emitted obsolete
  Java 8 source/target warnings from third-party plugin compilation.
- macOS/Linux: platform source and build workflow provided; not built or run on
  this Windows host. CI jobs have not been executed.
- No iOS target.

The included corpus does not cover every codec/profile combination. In particular,
HDR/Dolby Vision, Atmos, DTS-HD MA and embedded PGS require additional fixtures.
No visual verification, battery test, torrent delivery test or browser inspection
was performed.

## Windows follow-up

The user confirmed all video fixtures play and clip 12 displays subtitles.
Silent clips 1–4 and the steady tones in clips 5–12 match the fixture contents.
The user's report for the 4K60 fixture shows d3d11va-copy, approximately 60 FPS
and zero decoder/output drops in that snapshot.

After adding explicit fixture expectations, default subtitle selection and native
libass rendering, analysis and the Windows release build passed. The repeated
native smoke check decoded non-empty text from both SRT and ASS tracks in clip
12. Overall result remains 12/13 because the bundled Windows decoder cannot
initialize TrueHD audio. Native text decoding is not visual verification of ASS
styling. The original user report is preserved as sentorr-codec-report.json.

## Current libmpv comparison (2026-10-01)

The previously noted TrueHD gap is specific to the original bundled binary.
Its decoder list (mpv 0.36 git / FFmpeg n6.0) contains 135 entries and omits
TrueHD and MLP. The shinchiro 20261001 x86_64 build (mpv 0.41 git / FFmpeg
N-127043) contains 521 entries, including TrueHD and MLP.

The same fixture decodes without errors in the installed FFmpeg and current
standalone mpv. mpv writes 10 seconds of non-silent, 48 kHz six-channel PCM.
Replacing only libmpv-2.dll in an isolated copy of the Flutter release yields
13/13 successful native smoke checks, including TrueHD, SRT and ASS. This checks
media_kit integration; it does not certify audible quality or visual styling.

The isolated executable is build/windows-current-mpv/codec_lab.exe; select
clip 10 for TrueHD. Original build output retains the original bundled library.
A normal Flutter build still uses media_kit's original dependency until we pin
an updated native library in the build configuration.

Evidence: validation/windows-mpv-comparison.json (versions, hashes and summary),
validation/windows-current-mpv-smoke.json, decoder-list JSON files and
validation/windows-current-mpv-playback.txt. Downloaded binaries and PCM output
are ignored under validation/mpv-current/. The portable build came from the
Windows builds linked by https://mpv.io/installation/.
