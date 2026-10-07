# Home memory optimizations — 2026-10-06

The final controlled macOS profile runs reduced static Home's physical
footprint from **356.5 MiB to 237.0–244.2 MiB** (about 32–34%). With animation
enabled, footprint fell from **408.1 to 291.3 MiB** (about 29%). The visible
hero retains its existing resolution, artwork motion, ambient wash and theme.

These are fresh hidden processes with fixed local fixtures and isolated data,
not the exact footprint of the running developer debug app. Earlier same-size
baseline processes ranged from 360.5 to 429.0 MiB; physical footprint varies
more than the measured graphics allocation. No foreground speedup is claimed.

## Retained changes

- **Rasterize the ambient blur once at low resolution.** `BlurredImage`
  renders the cover-cropped wash into at most 360 × 720 pixels, with the
  logical sigma scaled to the raster size. The page paints that small result
  instead of filtering a viewport-sized scene. Its veil, gradient, parallax
  and crossfade remain. The original 360-pixel source decode remains bounded.
  Source changes and resize jobs discard stale results, allow one raster job
  per widget at a time, and dispose source clones, pictures and old outputs.
- **Reduce decoded keep-alive image caching from 64 to 16 MiB.** The disk
  cache and its user-configured budget are independent. Visible/current/next
  artwork is still retained as needed; this limit does not include every live
  image. Older cached images may need decoding again when revisited.
- **Bound the macOS Skia resource cache at 32 MiB.** Startup uses Flutter's
  documented [Skia resource-cache channel](https://api.flutter.dev/flutter/services/SystemChannels/skia-constant.html).
  This bounds reusable resources, not all live textures, frame buffers or
  MediaKit's separate video resources. Other platforms retain their native
  renderer-cache defaults. The existing macOS Skia/Metal setting remains.
- **Decode bundled logos at their physical display size.** The navigation
  mark and source icons use layout size × display pixel ratio rather than
  decoding their original asset resolution. A 32-point rail logo uses a
  64-pixel decode on the measured 2× display instead of its large original.
- **Bound rapid carousel transitions.** Only the current and latest outgoing
  artwork remain mounted during quick pager changes. Older overlapping
  transitions are skipped, avoiding a stack of full-size images. Normal
  transitions and current/next prefetch remain. This guard was regression
  tested; no native MiB saving is claimed for rapid clicks.

The earlier lazy destination mounting fix is retained. Home remains the
startup destination. No visible hero resolution cap, CDN rendition quality,
surface shadows or artwork effects were reduced.

## Final comparisons

All sizes are MiB. Each footprint/graphics value is the median of three
samples in one process. Graphics is `vmmap`'s owned unmapped graphics
allocation, not an additional amount to add to the physical footprint.

| Scenario | Footprint before | Footprint after | Graphics before → after |
| --- | ---: | ---: | ---: |
| Standard window, static | 356.5 | 237.0 / 244.2 | 176.9 → 96.3 |
| Standard window, animated | 408.1 | 291.3 | 200.8 → 86.6 |

The standard viewport was 2,200 × 1,456 physical pixels. Home was selected
before mounting, five fixed backdrops and five portrait posters were served
locally, and all five featured titles were visited during a 30-second warm-up.
Images had no pending loads before sampling at 0/10/25 seconds. GC preceded
Dart allocation snapshots; the post-GC heap stayed approximately 19.1 MiB.
The reduction is primarily native image/rendering memory.

The reported decoded-image cache fell from approximately **54.4 to 9.8 MiB**.
That cache statistic and the native graphics statistic can overlap in their
underlying resources; they are not additive savings.

A larger 3,000 × 1,856 physical-pixel viewport completed at **319.7 MiB**
footprint and **110.5 MiB** graphics allocation. There was no matching
larger-window baseline, so this is a smoke check, not a savings comparison.

## Candidates not retained

- A 16 MiB native cache budget produced 235.5 MiB static footprint and 91.4
  MiB graphics, versus 237.0–244.2 and 96.3 with 32 MiB. Its animated graphics
  saving was only 1.6 MiB. This small incremental saving did not establish a
  reason to halve the native cache again; 32 MiB retains more reuse capacity.
- Removing the ambient wrapper's repaint boundary increased static footprint
  to 309.7 MiB and graphics to 107.7 MiB. The boundary remains.
- An initial small-raster implementation applied the filter directly to the
  source draw and strengthened the tint in the light theme. The retained
  version filters the cover-cropped layer, restoring the reference appearance.
  Measurements of that intermediate version are saved separately and are
  not the final results above.

## Appearance and validation

Native before/after captures at 2,200 × 1,456 pixels were visually inspected
in both themes. Mean absolute RGB differences were **0.034–0.040 out of 255**
per channel; RMS differences were below 0.47. This checks the fixture scene,
not every artwork or screen size. Full-size foreground artwork remains sharp.

- **22 focused tests passed:** bounded blur output, stale loads, resize and
  disposal, rapid transition mounting, cache persistence/budget, native cache
  protocol, lazy pages, app shell, activity and offline Home.
- Scoped analysis of all changed Dart files passed. Plist lint and diff checks
  passed. The normal `lib/main.dart` macOS profile build succeeded with local
  defines; its bundle contains `FLTEnableImpeller=false`.
- Hidden native video checks advanced two seconds with zero reported decoder
  drops: H.264 and HEVC Main10 via VideoToolbox, AV1 via software decoding.
  Each process exited cleanly. These are short playback checks, not sustained
  performance, seeking, torrent load or HDR-fidelity certification.
- There were **25 successful experimental processes**: 16 memory comparisons,
  six appearance captures and three playback checks. Hidden animation rates
  varied substantially between batches, so no foreground FPS claim is made.
- The broader UI suite's 16 bootstrap-fixture failures were already reproduced
  against the original page stack in the earlier audit. This follow-up used
  the relevant focused suite rather than representing those failures as fixed.

The renderer's standard-color/wide-gamut tradeoff is unchanged from the
[earlier audit](MEMORY-2026-10-06.md). The developer's running app was preserved.
Restart the app to load all the changes; hot reload is insufficient for native
startup settings. Active image and video resources can exceed cache budgets.
The blank-shell/framework footprint remains; this is not a zero-memory target
or proof that every native allocation has been identified.

## Evidence and reproduction

Raw native memory maps, VM allocation profiles, telemetry, captures, fixtures,
launcher, complete experimental source and validation logs are saved at:

`/Users/sen/.codex/visualizations/2026/10/06/01a11198-94f0-70d3-8ef0-5cab2089f6e3/home-optimization/`

The launcher starts fresh processes with isolated roots and fixed window sizes.
Its baseline selects the original full-area blur, 64 MiB decoded cache and
original asset decoding. The final baseline restores the installed engine's
viewport-derived resource-cache budget; optimized processes use the retained
32 MiB budget. The standard transition timings do not activate the rapid-click
guard. Experimental environment flags are confined to the saved harness.
