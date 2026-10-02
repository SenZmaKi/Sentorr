import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../imdb/models.dart';
import '../watching/models.dart';
import '../watching/notifier.dart';
import 'catalog_rows.dart';

/// Movies and series the viewer is partway through, newest first.
final continueWatchingProvider = Provider<AsyncValue<List<WatchEntry>>>(
  (ref) => AsyncData(ref.watch(inProgressProvider)),
);

// PLACEHOLDER: followed series need their own persistence. Until then they
// derive from the trending chart so the row shows real titles. Replace this
// provider; consumers keep its shape.

/// Series the user follows; new episodes and seasons are tracked for these.
final followedSeriesProvider = FutureProvider<List<ImdbTitle>>((ref) async {
  final trending = await ref.watch(
    catalogRowProvider(CatalogRow.trending).future,
  );
  return trending.where((t) => t.canHaveEpisodes == true).take(10).toList();
});
