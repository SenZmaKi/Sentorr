# macOS native playback check

The 2026-10-02 crash reports contain two loaded copies of the same Mpv
framework. The failing stack is `TextureHW.initMPV` →
`mpv_render_context_create` → `m_config_cache_from_shadow`, with
`group_index >= 0` failing at line 554. The resolver had already selected a
season pack; no torrent download or decoding had begun.

A native C probe reproduced the exact assertion by creating a player with one
copy and creating its renderer with a second copy of the bundled framework.
Using one copy succeeded. This establishes the failure mechanism; it does not
establish how the duplicate copies were introduced in those app runs.

App startup now resolves the bundled framework's absolute path before
initializing MediaKit on macOS. This keeps Dart's loader aligned with the
framework linked by the native video plugin, including when
`LIBMPV_LIBRARY_PATH` points to a different copy. Other platforms retain their
normal library discovery. Fully stop and restart the app after this change;
a hot reload cannot unload duplicate native images.

## Regression check

Serve a known local fixture over HTTP (the sandbox cannot read arbitrary
repository paths directly):

```sh
python3 -m http.server 18767 --bind 127.0.0.1 \
  --directory tool/codec_lab/assets/media
```

In another terminal:

```sh
flutter run -d macos -t tool/player_native_smoke.dart
```

The check runs full app initialization, creates the native renderer, requires
exactly one loaded Mpv framework, and verifies playback progress and decoded
video width. It fails on rendering initialization or playback timeout. Supply
another fixture with `--dart-define=SMOKE_MEDIA=http://...` if needed.

The 2026-10-02 check passed with an intentional `LIBMPV_LIBRARY_PATH` override
pointing at a copied bundled library: one image loaded, playback reached two
seconds, and the decoded frame size was 1920×1080. A fresh startup before the
change also rendered successfully without an override. This verifies native
initialization and local HTTP playback, not live torrent swarm playback.
