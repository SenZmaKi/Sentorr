/// How much unwatched content automatic downloads hold: the pure
/// accounting smart downloads fill and evict by.
library;

import '../downloads/models.dart';
import '../following/models.dart';
import '../library/models.dart';
import '../library/notifier.dart';
import '../player/models.dart';
import '../watching/models.dart';

/// What [item] runs for when IMDb doesn't say.
const episodeEstimate = Duration(minutes: 45);
const movieEstimate = Duration(minutes: 110);

/// Unwatched runtime held by automatic downloads, and the smart ones to
/// delete or replace.
class Reserve {
  const Reserve({
    this.ready = Duration.zero,
    this.pending = Duration.zero,
    this.watched = const [],
    this.failed = const [],
    this.picks = const [],
  });

  /// Unwatched runtime on disk.
  final Duration ready;

  /// Unwatched runtime still downloading or queued.
  final Duration pending;

  /// Smart downloads the viewer has watched, to delete.
  final List<LibraryEntry> watched;

  /// Smart downloads that failed, to replace.
  final List<LibraryEntry> failed;

  /// Unwatched smart downloads, newest first.
  final List<LibraryEntry> picks;

  /// Ready and pending: what the reserve will hold once downloads finish.
  Duration get planned => ready + pending;
}

/// The reserve [entries] hold. Series auto-downloads count toward it but
/// only smart downloads are ever listed to delete.
Reserve reserveOf({
  required List<LibraryEntry> entries,
  required Map<String, DownloadItem> downloads,
  required Map<String, WatchEntry> history,
  required Map<String, FollowedSeries> followed,
}) {
  var ready = Duration.zero, pending = Duration.zero;
  final watched = <LibraryEntry>[], failed = <LibraryEntry>[];
  final picks = <LibraryEntry>[];
  for (final entry in entries) {
    if (!entry.automatic) continue;
    final smart = entry.origin == LibraryOrigin.smart;
    final download = downloads[entry.downloadId];
    if (isWatched(entry.item, history, followed)) {
      if (smart) watched.add(entry);
      continue;
    }
    final state = offlineStateOf(entry, download);
    if (state is DownloadFailed) {
      if (smart) failed.add(entry);
      continue;
    }
    final left = runtimeLeft(entry.item, history[entry.id]);
    if (state is Downloaded) {
      ready += left;
    } else {
      pending += left;
    }
    if (smart) picks.add(entry);
  }
  return Reserve(
    ready: ready,
    pending: pending,
    watched: watched,
    failed: failed,
    picks: picks,
  );
}

/// Whether the viewer finished [item], by its own record or, for an
/// episode, by how far into its series they got.
bool isWatched(
  PlaybackItem item,
  Map<String, WatchEntry> history,
  Map<String, FollowedSeries> followed,
) {
  if (history[item.id]?.finished ?? false) return true;
  final series = followed[item.series?.id];
  if (series == null || item.season == null || item.episode == null) {
    return false;
  }
  return series.seen((season: item.season!, episode: item.episode!));
}

/// What is left of [item] to watch, from where [watch] stopped.
Duration runtimeLeft(PlaybackItem item, WatchEntry? watch) {
  if (watch != null && watch.duration > Duration.zero) {
    return watch.remaining.isNegative ? Duration.zero : watch.remaining;
  }
  return item.runtime ?? (item.isEpisode ? episodeEstimate : movieEstimate);
}
