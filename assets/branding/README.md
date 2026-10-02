# Sentorr icon

`sentorr-icon-source.png` is the original artwork generated with the built-in
ImageGen tool. The folded ivory S and negative-space play symbol follow the
neutral, layered direction in `DESIGN.md`.

Final generation prompt:

> Use case: logo-brand. Create the production square app icon for Sentorr, a movie and TV torrent streaming app. A distinctive bold ivory S ribbon mark with a small right-facing play triangle formed by negative space at its center, on a charcoal black square background extending completely to all four edges. Restrained monochrome aesthetic, subtle layered depth and fine edge light on the mark, crisp geometric silhouette readable at 16 pixels. Center mark within the middle 62 percent of canvas with generous balanced padding. No text, letters beyond the abstract S, watermark, mockup, border, surrounding scenery or rounded outer corners. 1024x1024 icon artwork.

Regenerate platform sizes with Python 3 and Pillow:

```sh
python3 tool/generate_icons.py
```

The script produces the bundled `assets/images/sentorr-icon.png`, the existing
tray asset, macOS AppIcon sets, Windows multi-resolution ICO files, Android
launcher density variants, and the Linux packaging icon. The design demo and
codec lab share the artwork wherever their platform runners exist.

The Android manifest, macOS asset catalogs, Windows resource files and Flutter
asset directory already reference these locations. Linux installs its own
packaging icon through CMake. The source artwork is not bundled at runtime.

Only the macOS build has been verified on this host; Windows, Android and Linux
assets require their respective platform builds to verify native integration.
