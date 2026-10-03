import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/manager.dart';
import '../downloads/models.dart';
import '../library/models.dart';
import '../library/notifier.dart';

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
