import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../settings/notifier.dart';
import 'filters.dart';
import 'repository.dart';
import 'resolver.dart';

final torrentRepositoryProvider = Provider<TorrentRepository>(
  (ref) => TorrentRepository.defaults(ref.watch(networkClientProvider).dio),
);

/// Resolves against the sources the viewer has left enabled.
final torrentResolverProvider = Provider<TorrentResolver>((ref) {
  final repository = ref.watch(torrentRepositoryProvider);
  final sources = ref.watch(settingsProvider.select((s) => s.sources));
  return TorrentResolver(
    TorrentRepository(repository.sources.where((s) => sources.enabled(s.id))),
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
