import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../imdb/models.dart';
import '../library/models.dart';
import '../library/notifier.dart';
import '../sync/elsewhere.dart';
import '../watching/models.dart';
import '../watching/notifier.dart';

/// Finished downloads, newest first: what still plays offline.
final finishedDownloadsProvider = Provider<List<LibraryEntry>>((ref) {
  final downloads = {
    for (final d in ref.watch(downloadsProvider).value ?? <DownloadItem>[])
      d.id: d,
  };
  return [
    for (final e in ref.watch(libraryProvider))
      if (offlineStateOf(e, downloads[e.downloadId]) is Downloaded) e,
  ]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
});

/// Whether movie or episode [id] plays without the internet: downloaded
/// here, or finished on a paired device in reach.
final playableOfflineProvider = Provider.family<bool, String>(
  (ref, id) =>
      ref.watch(finishedDownloadsProvider).any((e) => e.item.id == id) ||
      ref.watch(elsewhereOfProvider(id))?.finished == true,
);

/// A downloaded movie or series, and the file Play starts for it.
typedef OfflinePick = ({ImdbTitle show, LibraryEntry next, int count});

/// The offline spotlight: up to five downloaded movies and series, most
/// recently downloaded first.
final offlineSpotlightProvider = Provider<List<OfflinePick>>((ref) {
  final byShow = <String, List<LibraryEntry>>{};
  for (final e in ref.watch(finishedDownloadsProvider)) {
    byShow.putIfAbsent((e.item.series ?? e.item.title).id, () => []).add(e);
  }
  final history = {for (final w in ref.watch(watchHistoryProvider)) w.key: w};
  return [
    for (final MapEntry(key: id, value: entries) in byShow.entries.take(5))
      (
        show: entries.first.item.series ?? entries.first.item.title,
        next: _next(entries, history[id]),
        count: entries.length,
      ),
  ];
});

/// The episode being watched if it is here, else the first downloaded one
/// after it, else the first downloaded.
LibraryEntry _next(List<LibraryEntry> entries, WatchEntry? watched) {
  if (entries.length == 1 || watched == null) {
    return entries.reduce((a, b) => _order(a) <= _order(b) ? a : b);
  }
  final sorted = [...entries]..sort((a, b) => _order(a) - _order(b));
  final at = (watched.season ?? 0) * 10000 + (watched.episode ?? 0);
  return sorted.firstWhere(
    (e) => watched.finished ? _order(e) > at : _order(e) >= at,
    orElse: () => sorted.first,
  );
}

int _order(LibraryEntry e) =>
    (e.item.season ?? 0) * 10000 + (e.item.episode ?? 0);
