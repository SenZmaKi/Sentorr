# Sync performance improvements

Implemented 5 October 2026.

- Shared libraries read each completed file with one asynchronous stat instead
  of three synchronous filesystem calls. A bounded worker pool checks at most
  four files concurrently. Files remain revalidated on every request; no stale
  filesystem cache can hide a replacement or deletion. Library shape changes
  include paths, release hashes and file indexes.
- Follow merges group contributions per series, encode and deduplicate each
  contribution once, then sort once and fold fields without accumulated
  provenance. All original contributors remain available for tombstone
  filtering and deterministic convergence.
- Library polls send the last completed-media revision. Matching responses
  omit media and continue sending live download progress; receivers retain
  the existing media objects. Older peers still exchange full libraries.
- Drive caches decoded snapshots by file id and provider checksum. Changed
  checksums trigger downloads; missing checksums disable reuse. Reads and
  optional cleanup use at most four concurrent requests, preserve deterministic
  merge order, and wait for active workers before retrying a disappeared file.
  Publishing still precedes deletion of only previously observed snapshots.
  Concurrent token refreshes share one request.
- JSON persistence coalesces pending replacements. Each caller completes only
  after its snapshot or a newer replacement is durable. Writes already in
  flight complete normally; errors do not poison subsequent saves. `flushed`
  covers the full drain, including snapshots queued during disk IO.
- Unchanged or regressing follow progress consumes neither a save nor a
  logical revision. New episodes and actual progress continue to persist;
  watch-history persistence and final playback flushes remain in place.

Regression tests demonstrate a 20-save burst producing one atomic replacement,
20 saves during an active replacement producing only one additional write,
checksum reuse and invalidation, a four-request Drive concurrency ceiling,
conditional HTTPS responses, retained media with updated progress, and stable
merging of 200 distinct contributors supplied twice and in reversed order.
These are operation-count and correctness checks, not measured device latency
or live Google Drive throughput benchmarks.

Validation: full `flutter test --no-pub` passed 680 tests. Scoped analysis of
the sync, backup, following, persistence changes and regression tests was
clean; `git diff --check` was clean. Whole-repository analysis reported two
missing `isCurrent` arguments in `tool/performance/audit.dart` during concurrent
playback work, outside this change's scope.
