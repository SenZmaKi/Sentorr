# Performance

Use the [production audit harness](../../tool/performance/README.md) for new
measurements. Keep raw memory maps, stack samples and run output outside the
repository; record the revision, workload, platform and validation limits with
any conclusions.

Retained explanations for current implementation decisions:

- [macOS renderer and lazy page mounting](MEMORY-2026-10-06.md): why the macOS
  bundle selects Skia/Metal, the standard-color tradeoff, and when to recheck it.
- [Home artwork and cache optimizations](HOME-OPTIMIZATION-2026-10-06.md): bounded
  blur rasterization, decoded-image/resource caches and carousel image lifetime.
- [Player byte path and resource lifetime](PLAYER-IMPROVEMENTS-2026-10-05.md):
  scheduler work, bounded HTTP batching and parked-session expiry.

These are dated measurements of specific revisions and controlled workloads,
not current speed or memory guarantees. Superseded initial reports and raw
2 October profiling dumps are available in Git history.
