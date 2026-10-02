import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../imdb/models.dart';
import 'catalog_rows.dart';

// PLACEHOLDER: watch history and followed series need the persistence layer.
// Until then both derive from the trending chart so the personal rows show
// real titles. Replace these two providers; consumers keep their shapes.

/// A partially watched title.
class ResumeEntry {
  const ResumeEntry({required this.title, required this.progress});

  final ImdbTitle title;

  /// Fraction watched, 0–1.
  final double progress;

  Duration? get remaining {
    final seconds = title.runtimeSeconds;
    if (seconds == null) return null;
    return Duration(seconds: (seconds * (1 - progress)).round());
  }
}

final continueWatchingProvider = FutureProvider<List<ResumeEntry>>((ref) async {
  final trending = await ref.watch(
    catalogRowProvider(CatalogRow.trending).future,
  );
  return [
    for (final (i, title) in trending.skip(5).take(6).indexed)
      // Fixed spread of progress values, stable across rebuilds.
      ResumeEntry(
        title: title,
        progress: const [.62, .31, .84, .55, .12, .4][i],
      ),
  ];
});

/// Series the user follows; new episodes and seasons are tracked for these.
final followedSeriesProvider = FutureProvider<List<ImdbTitle>>((ref) async {
  final trending = await ref.watch(
    catalogRowProvider(CatalogRow.trending).future,
  );
  return trending.where((t) => t.canHaveEpisodes == true).take(10).toList();
});
