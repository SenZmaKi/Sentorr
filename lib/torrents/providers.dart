import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../settings/notifier.dart';
import '../shared/source_directory/repository.dart';
import 'models.dart';
import 'metadata_fetcher.dart';
import 'sources/pirate_bay.dart';
import 'sources/yts.dart';
import 'sources/bitsearch.dart';
import 'filters.dart';
import 'repository.dart';
import 'resolver.dart';

final torrentMetadataProvider = Provider<TorrentMetadataFetcher>(
  (ref) => TorrentMetadataFetcher(ref.watch(networkClientProvider).dio),
);

final torrentRepositoryProvider = Provider<TorrentRepository>((ref) {
  final dio = ref.watch(networkClientProvider).dio;
  ref.watch(sourceDirectoryProvider);
  final directory = ref.read(sourceDirectoryProvider.notifier);
  return TorrentRepository([
    PirateBaySource(
      dio,
      endpointResolver: () => directory.endpointFor(TorrentSourceId.pirateBay),
    ),
    YtsSource(
      dio,
      endpointResolver: () => directory.endpointFor(TorrentSourceId.yts),
    ),
    BitsearchSource(
      dio,
      endpointResolver: () => directory.endpointFor(TorrentSourceId.bitsearch),
    ),
  ], beforeSearch: ref.read(sourceDirectoryProvider.notifier).waitForRefresh);
});

/// Resolves against the sources the viewer has left enabled.
final torrentResolverProvider = Provider<TorrentResolver>((ref) {
  final repository = ref.watch(torrentRepositoryProvider);
  final sources = ref.watch(settingsProvider.select((s) => s.sources));
  return TorrentResolver(
    TorrentRepository(
      repository.sources.where((s) => sources.enabled(s.id)),
      beforeSearch: repository.beforeSearch,
    ),
  );
});

/// The viewer's picker filters, kept for the session so the launch dialog
/// and the player's picker narrow the same way.
final torrentFiltersProvider =
    NotifierProvider<TorrentFiltersNotifier, TorrentFilters>(
      TorrentFiltersNotifier.new,
    );

class TorrentFiltersNotifier extends Notifier<TorrentFilters> {
  @override
  TorrentFilters build() => const TorrentFilters();

  void set(TorrentFilters filters) => state = filters;
}
