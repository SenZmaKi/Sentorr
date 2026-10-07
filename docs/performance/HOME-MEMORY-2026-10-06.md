# Home component memory isolation

Home is still the production startup destination. This follow-up isolates
Home under the current Skia/Metal renderer rather than changing the renderer
again. It identifies two primary targets: the ambient blur and hero artwork.

## Method

Sixteen fresh hidden profile processes used isolated data, the same production
navigation shell, a 2,200 × 1,456 physical-pixel viewport, and fixed local
artwork. Home was selected before mounting. Static comparisons disabled
animations, warmed for 30 seconds, checked for pending image loads, then took
three VM/`vmmap` samples at 0, 10 and 25 seconds. Each process exited cleanly.
The running developer app and its data were preserved.

The first ten cases reused five landscape fixtures for both hero and posters,
matching the prior audit. The final six used separate real portrait posters
for shelves. This corrects an unrealistic shelf-cover decode cost in the
original fixtures. Catalog rows repeat five titles; this is controlled
component attribution, not an exact measurement of the user's entire catalog.

Values are MiB, medians of three samples. Graphics means `vmmap`'s owned
unmapped graphics allocation. It is not an additional amount to add to the
physical footprint, and its individual native owners have not all been traced.

## Blank Home and separate components

The shell remained unchanged; only Home's body varied.

| Home body | Footprint | Graphics | Reported decoded image cache |
| --- | ---: | ---: | ---: |
| Blank | 150.4 | 12.0 | 4.0 |
| Ambient only | 184.1 | 44.8 | 5.6 |
| Ambient only, blur removed | 188.2 | 27.2 | 5.6 |
| Hero only, five titles cycled | 288.0 | 102.9 | 48.5 |
| Hero only, artwork removed | 165.3 | 29.5 | 4.0 |
| Shelves only | 176.5 | 28.9 | 12.3 |
| Hero and shelves, no ambient | 325.9 | 120.1 | ~56 |
| Full Home, images removed | 189.0 | 44.0 | 4.0 |
| Full Home | 385.4 | 185.9 | 58.4 |

Blank Home is near the other destinations' cost. The hero's artwork accounts
for approximately 123 MiB of footprint and 73 MiB of graphics allocation in
its isolated comparison. Its text, frame and controls add relatively little.
The shelves are not the dominant contributor in this fixture set, even when
removing the hero leaves more viewport space for them.

The post-GC Dart heap was 15.9 MiB for blank Home, 16.7 MiB for the hero,
16.5 MiB for the hero without artwork, and 19.1 MiB for full Home. The large
differences are native image/rendering resources, not Dart model retention.

## Full composition with portrait posters

| Configuration | Footprint | Graphics | Image cache |
| --- | ---: | ---: | ---: |
| Full Home | 423.2 | 179.2 | 54.4 |
| Entire ambient background removed | 318.3 | 112.1 | 52.1 |
| Only ambient blur removed | 369.0 | 116.0 | 54.4 |
| Full Home, cache budget reduced to 16 MiB | 388.3 | 175.8 | 9.8 |

Removing only the blur eliminates 63.2 MiB of graphics allocation while the
reported decoded cache is unchanged. Removing the entire ambient background
eliminates 67.1 MiB. This identifies the filter as the major native allocation
in that background, rather than its small decoded image or color overlays.

The ambient source is decoded at 360 pixels wide, but `ImageFiltered` blurs
the enlarged painted scene with sigma 64. A small source decode does not
therefore bound the filter's rendering cost to a small texture.

Component costs are not additive: the ambient filter costs more in the full
composition than it does by itself. These measurements isolate the widget
path responsible, not every engine intermediate or cache allocation.

Total footprint is noisier than the graphics category: for example, the
no-blur full-Home samples ranged from 308.5 to 369.1 MiB while graphics stayed
116.0 MiB. The earlier full-Home Skia run had 472.9 MiB footprint with the
same 185.9 MiB graphics allocation measured in the first fixture set here.
Use these as allocation attribution, not a promised fixed savings percentage.

## Carousel history versus decoded cache

| Hero-only configuration | Footprint | Graphics | Image cache |
| --- | ---: | ---: | ---: |
| First title, current and next artwork loaded | 268.7 | 58.8 | 21.8 |
| Five titles cycled | 288.0 | 102.9 | 48.5 |
| Five titles cycled, 16 MiB cache budget | 238.8 | 103.5 | 9.5 |

Cycling adds 44.1 MiB of graphics allocation. Reducing Flutter's decoded-image
cache lowers physical footprint but does not remove that graphics allocation.
The next artwork is deliberately prefetched, and current/next images remain
live even when an image-cache entry is evicted. Native renderer resources can
also remain retained; these data do not establish their exact owners or prove
a leak. Merely lowering the global cache cap will not solve the whole issue.

## Optimization order

1. **Ambient blur:** investigate producing a small blurred wash once per
   artwork/size and painting that result, instead of filtering the enlarged
   scene. Preserve the existing veil, gradient, parallax and crossfade. Compare
   appearance at multiple sizes and both themes, then repeat this exact native
   measurement; the candidate has not yet been implemented or validated.
2. **Hero artwork/carousel:** separately measure decode dimensions, current/next
   prefetch and native retention after title changes. Bound old decoded entries
   without sacrificing the resolution of visible artwork. A smaller cache is
   measurable but brings redecoding costs and leaves the graphics issue.
3. **Shelves:** lower priority based on these initial-viewport measurements.
   Real distinct catalogs and long scrolling need their own retention audit.

No production Home effects, image quality, cache budgets or startup destination
were changed in this follow-up. The exclusion and cache flags exist only in
the isolated harness. This experiment did not measure foreground frame rates,
long-running leaks, playback or concurrent torrent load.

## Evidence

Raw VM allocation snapshots, native memory maps, telemetry, fixture images,
launcher, complete experimental Dart files and build logs are saved at:

`/Users/sen/.codex/visualizations/2026/10/06/01a11198-94f0-70d3-8ef0-5cab2089f6e3/home-components/`

See [the earlier page and renderer audit](MEMORY-2026-10-06.md) for the lazy
mounting fix, renderer tradeoffs and existing test/native playback validation.
