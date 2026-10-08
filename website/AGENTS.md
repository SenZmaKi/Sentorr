# Sentorr website

Astro marketing site published to GitHub Pages at `https://senzmaki.github.io/Sentorr/`, beside the signed update feeds (`update-manifest.json`, `appcast*.xml`, `source-directory.json`). Both `.github/workflows/deploy-source-directory.yml` and the release workflow build it into `site/`; never let the site write those feed filenames.

## Structure

- The site is drawn with the app's own widgets so it reads as Sentorr: `AppShell` (rail on the canvas, page on a panel inset 8; compact top bar and bottom navigation), `SectionHeader`, `Group`/`Tile` (the settings group and tile), `MetaLine`, `LaunchCard` (the play launch dialog) and Material icons via `Icon` (`Icons.*_rounded`/`_outlined`). Mirror the matching Flutter widget in `../lib/ui/` when adding one.
- `src/layouts/Layout.astro`: head, SEO and theme bootstrap; `src/components/`: sections and widgets; `src/pages/`: routes.
- `src/lib/site.ts` owns links, release asset names and the `url()` helper. Every internal link goes through `url()` because the site lives under the `/Sentorr` base.
- `src/styles/global.css` owns tokens. They mirror the app's roles in `../DESIGN.md` (canvas, surface, surfaceControl, depth recipes, Barlow / Geist Mono). Components use the tokens and shared classes (`panel`, `raised`, `button`), not raw colors.
- Screenshots live in `src/assets/screenshots/{desktop,mobile}/` and are listed in `src/lib/screenshots.ts`. Capture them without touching the developer's running app: `flutter build macos --profile`, copy the `.app` to a scratch folder, set its `CFBundleIdentifier` to `com.sentorr.website-shots` (its own sandbox container, so fresh data) and re-sign it ad hoc with `macos/Runner/DebugProfile.entitlements`. Write the window size to `state/window.json` in that container (`{"x":20,"y":40,"width":1280,"height":800}`, or 390 × 844 for the phone layout), launch it with `open -g -n`, and capture the window with `screencapture -x -o -l <windowId>`. Crop the macOS title bar off phone shots and save as WebP (`cwebp -q 88 -m 6`); the README reuses these files.
- Download links are built from `../pubspec.yaml`'s version (the release tag is `v<version>`); the per-platform processor picker swaps the asset name.

## Development

Start the dev server in the background: `npx astro dev --background`; manage it with `astro dev stop|status|logs`. Run `npm run check` and `npm run build` before committing.
