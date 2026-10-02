# Performance improvements — 2026-10-02

Based on [the audit](AUDIT-2026-10-02.md), this change targets unnecessary UI work and artwork retention. The audit already found bounded torrent buffering and hardware video decoding, so download scheduling, stream buffering and decoder settings are unchanged.

## Changes

- `AppActivity` gates UI tickers using app lifecycle and desktop window visibility. Tray hide, close-to-tray and minimize mute animations; restore resumes them without unmounting screens. Visible but unfocused desktop windows still animate. Background services remain outside this gate.
- The spotlight mounts its current and next backdrop, with a temporary outgoing image during crossfade, rather than all five full-size backdrops. The ambient wash also retains only its current/outgoing artwork. Repaint boundaries isolate artwork and animated pager progress from static content.
- Artwork decoding follows display width/device pixel ratio, capped at 2560 pixels; the blurred ambient wash decodes at 360 pixels. Flutter's decoded keep-alive image cache is limited to 64 MiB. This is separate from the existing disk-cache preference, and does not cap mounted images, GPU textures or total application memory.
- Title details use an auto-disposing provider. Screens share a request while subscribed; listener-free queue requests remain alive until completion. Unused details are released, with the existing HTTP disk cache available on later visits.
- Ken Burns animation explicitly stops when deactivated and resets when reduced motion is enabled.

## Native check

A fresh baseline was captured from the working sources before these changes, including the concurrent responsive UI work. Both runs used a separately built macOS **profile** app, production bootstrap and home screen, a fresh isolated data root, and the existing static audit harness. The native window remained hidden throughout; no user settings or downloads were used.

| Measurement | Before | After |
| --- | ---: | ---: |
| Physical footprint at entry to `home_idle` | 843.4 MiB | 273.5 MiB |
| Peak physical footprint by that sample | about 1.1 GiB | 359.5 MiB |
| Mean CPU during 20-second `home_idle` | 0.79% | 0.10% |
| Median resident memory during `home_idle` | 70.5 MiB | 30.1 MiB |

CPU percentages represent one core. Resident memory excludes much of the graphics footprint; physical footprint is the more useful comparison here. Both catalogs returned five titles.

These are early hidden-home snapshots, **not a reliable steady-state improvement**. After loading, the baseline retained about 83.4 MiB in decoded cache with 19 live image streams. The improved run initially retained only 4 MiB with no live streams, but artwork arrived later: its final decoded-cache observation was 49.4 MiB with 12 live streams, and the later `home_tickers_resumed` footprint sample was 936 MiB. The resumed phase also averaged 13.88% CPU over its incomplete 14-second sample. The smaller idle snapshot therefore cannot establish a 68% memory reduction. Live response timing and native lifecycle/rendering variation confound this comparison.

The improved app exited with status zero after logging a shutdown during `home_tickers_resumed`, before the harness's `blank_ui` and `complete` events. That run verifies launch/catalog loading, but does not establish completion of the full static workload or the cause of the early shutdown. The baseline did complete normally.

The fresh baseline was already much quieter after loading than the original audit's 14.8% home-idle result. No guaranteed CPU percentage reduction is claimed. No new torrent playback/download throughput improvement is claimed either; those workloads were measured in the original audit, not repeated for this UI change.

Raw samples, events and summaries are under [`2026-10-02/improvements/`](2026-10-02/improvements/). A dependable numeric comparison needs fixed local artwork, an explicit image-ready barrier, recorded window/lifecycle visibility, and a complete run after warmup. The tests below establish the intended resource lifetimes independently of these variable native measurements.

## Validation

- 21 focused tests passed: visibility/lifecycle animation gating, preservation of widget state and background timer activity, spotlight preloading/wraparound, metadata lifetime including queue requests, reduced motion, persistent image cache and download queue behavior.
- Wider UI/IMDb/persistence/queue run: 137 passed, two failures in bottom-navigation disposal (`_NavExtent` used after disposal). Both failures also reproduce in the earlier snapshot with the original title-detail provider.
- The first full `flutter analyze` run found no errors or warnings, with one informational diagnostic in `preview_layout.dart`. A later full run, after concurrent download/library edits, reported errors in `library/planner.dart` (unavailable cancellation method and nullable candidates), plus informational diagnostics in `downloads/batches.dart`. These files were not changed by this performance work.
- Scoped analysis of the performance implementation, harness and new tests passed with no issues.
- Hidden macOS profile build succeeded. No browser inspection or visible UI validation was performed.

## Commit verification

The staged performance-only snapshot was exported and checked separately from concurrent changes. Its focused suite passed all 19 tests (the working-tree run above included two additional concurrent queue tests), and `flutter analyze lib test tool/performance` found no issues. Full-root analysis of that export also visits independent codec/streaming lab projects whose dependencies were not initialized there.
