# Torrent HTTP performance audit

Measured locally on macOS arm64, using AOT-compiled Dart executables and the real production engine/loopback HTTP endpoint. Thumbnail generation, Flutter, mpv, and player UI were excluded from both variants.

## Comparison controls

- Previous implementation: Git commit `6173abbf828b6647a4d65c98047c28198562998a`.
- New implementation: frozen working-tree copy of `packages/torrent_stream/lib` taken before benchmarking; its source digest is in `results.json`.
- Identical native libtorrent binary in both builds, verified with SHA-256.
- Identical worker source, 256 MiB deterministic fixture, and zero raw-piece cache budget, matching Sentorr’s previous app configuration.
- Metadata generation, file verification, endpoint setup, and one 64 KiB warmup completed before measurement.
- Three fresh-process runs per variant/scenario/piece size; alternating old/new ordering. No benchmarks ran concurrently.
- This is warm-cache file serving. The OS cache was not flushed, and no Internet peers or download contention were involved.
- Sequential: one 4 MiB HTTP range. Seeks: 24 deterministic unaligned 64 KiB HTTP range requests (1.5 MiB total). Every returned byte was verified.
- Wall time covers the complete HTTP workload. CPU time is process-wide, including the engine isolate and native threads; it can exceed elapsed time.
- Memory is sampled process resident memory (RSS), including native/Dart allocations. An external macOS sampler runs every 5 ms, including when FFI blocks Dart. It excludes the OS’s separate file cache and all mpv/UI memory. Short-lived peaks can be missed.

## Sequential reads: medians of three runs

| Piece size | Old time | New time | Speedup | Old throughput | New throughput | Old CPU time | New CPU time | Old peak RSS | New peak RSS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 256 KiB | 1276.8 ms | 43.5 ms | 29.3× | 3.13 MiB/s | 91.89 MiB/s | 151.7 ms | 66.5 ms | 54.5 MiB | 39.7 MiB |
| 1 MiB | 1277.9 ms | 44.6 ms | 28.7× | 3.13 MiB/s | 89.76 MiB/s | 248.8 ms | 68.7 ms | 70.7 MiB | 38.6 MiB |
| 16 MiB | 1275.3 ms | 45.6 ms | 28.0× | 3.14 MiB/s | 87.78 MiB/s | 1280.8 ms | 69.8 ms | 127.0 MiB | 40.2 MiB |
| 128 MiB | 14915.2 ms | 45.0 ms | 331.3× | 0.27 MiB/s | 88.85 MiB/s | 19224.6 ms | 69.3 ms | 792.4 MiB | 39.0 MiB |

## Seeks: medians of three runs

The p95 column is the median of each run’s p95 request latency (24 requests per run); it is not a pooled percentile.

| Piece size | Old total time | New total time | Old p95 | New p95 | Old CPU time | New CPU time | Old peak RSS | New peak RSS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 256 KiB | 596.9 ms | 38.3 ms | 40.24 ms | 2.57 ms | 92.5 ms | 43.1 ms | 48.1 MiB | 31.1 MiB |
| 1 MiB | 477.1 ms | 35.0 ms | 21.00 ms | 2.00 ms | 106.7 ms | 40.2 ms | 86.9 MiB | 30.9 MiB |
| 16 MiB | 476.0 ms | 33.2 ms | 20.94 ms | 1.87 ms | 586.9 ms | 37.5 ms | 286.9 MiB | 30.4 MiB |
| 128 MiB | 5578.7 ms | 39.1 ms | 244.78 ms | 2.39 ms | 7240.8 ms | 44.6 ms | 924.7 MiB | 30.6 MiB |

## Findings

1. The old implementation repeatedly reads and copies an entire piece for each 64 KiB HTTP chunk. With a zero cache budget, the sequential workload requests 64 whole-piece loads: 1 GiB of piece payload for 16 MiB pieces, or 8 GiB for 128 MiB pieces, to deliver 4 MiB. These byte counts follow from the serving loop; they are not physical disk-traffic measurements. The OS may cache the underlying file reads.
2. Whole-piece reads also wait for the native alert pump, which runs every 20 ms. At one completed 64 KiB chunk per cycle, that cadence corresponds to roughly 3.125 MiB/s. The observed old throughput near 3.13 MiB/s for smaller pieces is consistent with this bottleneck; the benchmark does not independently attribute every millisecond to polling versus copying.
3. Large pieces make copying and allocation dominate. The 128 MiB old path delivered only about 0.27 MiB/s and approached 925 MiB sampled RSS during seeks. This is allocation churn/heap/native-buffer behavior, not evidence of a permanent leak.
4. The new path avoids both the whole-piece payload copies and their per-chunk alert wait. Sequential throughput remained around 88–92 MiB/s across all tested piece sizes. Its sampled peak RSS was about 38.6–40.2 MiB sequentially and 30.4–31.1 MiB during seeks.
5. With 16 MiB pieces, sequential CPU time fell about 94.5%, from 1,280.8 to 69.9 ms. Sequential peak RSS fell about 68.4%. Seek p95 fell from 20.94 to 1.87 ms; seek peak RSS fell from 286.9 to 30.4 MiB.
6. No regression was observed in these measured workloads. Three repetitions establish a large local effect, not a cross-device statistical guarantee.

## Boundaries and next validation

- This does not measure video decoding, dropped frames, mpv buffering, thumbnail generation, or total app memory. In particular, a 40 MiB benchmark process does not imply the complete app uses 40 MiB.
- It does not reproduce the exact movie, seek history, or swarm from the original recording, so it cannot prove that recording’s four-second stall is eliminated.
- All file contents were already available. Missing-piece latency, cold storage, download throughput, retained-partfile export/startup costs, and concurrent thumbnail I/O are outside this timing comparison.
- Correctness around missing pieces, pending writes, cancellation, storage moves, renames, shared-piece files, and retained-cache recovery was tested separately in the implementation test suite.
- macOS only. Windows, Linux, and Android need device measurements; do not extrapolate these exact numbers to them.
- Normal Dart file reads still copy small buffers and open/close file handles per chunk. This audit provides no current performance justification for a native `sendfile` layer or an extra HTTP payload cache.

## Reproduction and artifacts

```sh
python3 tool/stream_io_audit/run.py /tmp/sentorr-stream-io-audit-repro
```

The runner snapshots the current HEAD as the old variant and the current working package as the new variant. To reproduce this historical baseline after HEAD changes, select the recorded commit in a separate checkout first. Avoid running other performance work concurrently.

`results.json` contains all 48 runs, medians, source and native-library hashes, and the exact worker source used for the recorded measurements. `worker.dart` has only import/style cleanup relative to that embedded measured source. Both variants in the recorded audit used the same embedded source.

Dart: `Dart SDK version: 3.13.1 (stable) (Tue Aug 18 01:00:59 2026 -0700) on "macos_arm64"`.
Native library SHA-256: `63d127823d55219102740c41d243ce8664f8006ac60558b70ba1ffe9824acb7b`.
