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

## Light variant and live switching

`sentorr-icon-light-source.png` is the matching ImageGen edit: graphite ribbon
on a pale neutral background, with the same silhouette and play cutout.

Edit prompt: Preserve the folded S ribbon silhouette, negative-space play
triangle, geometry, framing and padding. Replace the charcoal background with
neutral off-white (#F3F3F3), and the ivory ribbon with graphite folded shading
and subtle edge highlights. Grayscale only; no added elements, text or outer
rounding. Matching light companion, not a redesign.

`SentorrBrand` resolves assets centrally from the app theme. The navigation
logo, desktop tray, running macOS Dock icon and Windows window/taskbar icon
follow light/dark/system settings live. The macOS channel uses AppKit's
`applicationIconImage`; Windows uses `window_manager.setIcon`. Linux's installed
launcher retains the dark artwork. Finder, shortcuts and
other installed launcher resources also retain dark artwork; running icon
updates do not modify the app bundle. Failed light updates attempt dark fallback.

Android follows the resolved app theme too. The manifest launches through two
activity aliases, `.LauncherDark` (`ic_launcher`, enabled by default) and
`.LauncherLight` (`ic_launcher_light`); `AppAppearance.kt` enables the matching
one when the app goes to the background. With the system mode the icon updates
only while Sentorr runs.

The launch splash shows `splash_icon_{light,dark}` on `splash_background_*`,
which matches each icon's background, so Android 12+ shows no separate icon
chip. The default `LaunchTheme` follows the phone's night mode; on Android 13+
an explicit app theme persists `SplashLight`/`SplashDark` for the next launch
via `setSplashScreenTheme`. Older versions follow the phone.

The generator includes both runtime variants (PNG for logo/tray/Dock and ICO
for Windows), while preserving dark build-time platform assets.

Windows, Android and Linux require their respective platform builds to verify
native integration on those platforms.
