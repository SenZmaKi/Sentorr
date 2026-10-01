# Sentorr design demo

Throwaway showcase of the `DESIGN.md` direction: theme layers, the `SurfaceDepth` vocabulary and the fundamental components, in light and dark modes.

```sh
flutter run -d macos
RENDER_DIR=/some/dir flutter test   # renders every page in both modes to PNGs
```

- `lib/ui/shared/theme/`: tokens, semantic colors, depth styles, typography, `ThemeData`.
- `lib/ui/components/`: shared widgets that consume the theme only.
- `lib/ui/demo/`: pages (Discover, Title detail, Player, Settings, Components) with fictional data and generated artwork.

Geist fonts are bundled under `assets/fonts/` with their license (`LICENSE.txt`).
