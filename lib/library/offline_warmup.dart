import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../app/services.dart';
import '../imdb/images.dart';
import '../imdb/models.dart';
import '../imdb/providers.dart';
import '../shared/net/online.dart';
import '../titles/episodes.dart';
import 'notifier.dart';

final _log = Logger('sentorr.offline');

/// Artwork widths kept on disk for downloads: washes and cards, then heroes.
/// Offline, artwork shows whichever size is nearest.
const _artworkWidths = [360, 1080];

/// While online, keeps what downloaded titles need offline in the caches:
/// their details, artwork, and the first page of each downloaded season.
/// Bootstrap reads it once; it follows the library from then on.
final offlineWarmupProvider = Provider<void>((ref) {
  final warmed = <String>{};
  var running = false;

  Future<void> warm() async {
    if (running || !ref.read(onlineProvider)) return;
    running = true;
    try {
      final shows = <String, ({ImdbTitle show, Set<int> seasons})>{};
      for (final e in ref.read(libraryProvider)) {
        final show = e.item.series ?? e.item.title;
        final s = shows.putIfAbsent(
          show.id,
          () => (show: show, seasons: <int>{}),
        );
        if (e.item.series != null && e.item.season != null) {
          s.seasons.add(e.item.season!);
        }
      }
      for (final (:show, :seasons) in shows.values) {
        final keys = [show.id, for (final n in seasons) '${show.id}/$n'];
        if (keys.every(warmed.contains)) continue;
        if (!ref.mounted || !ref.read(onlineProvider)) return;
        await _warmTitle(ref, show, seasons);
        warmed.addAll(keys);
      }
    } on Object catch (error) {
      // Left unmarked, so the next change or reconnection tries again.
      _log.fine('Offline warm-up stopped', error);
    } finally {
      running = false;
    }
  }

  ref.listen(libraryProvider, (_, _) => warm());
  ref.listen(onlineProvider, (was, online) {
    if (was == false && online) warm();
  });
  Future.microtask(warm);
});

Future<void> _warmTitle(Ref ref, ImdbTitle show, Set<int> seasons) async {
  final details = await ref.read(titleDetailsProvider(show.id).future);
  final cache = ref.read(imageCacheProvider);
  for (final image in {
    ?(details.title.poster ?? show.poster),
    ?details.backdropCandidate,
  }) {
    for (final width in _artworkWidths) {
      final url = imdbImageUrl(image.url, width: width.toDouble());
      if (await cache.getFileFromCache(url) == null) {
        await cache.downloadFile(url);
      }
    }
  }
  final imdb = ref.read(imdbRepositoryProvider);
  for (final season in seasons) {
    // The same first page the episode list asks for, so it is cached.
    await imdb.getEpisodes(
      show.id,
      season,
      limit: SeasonEpisodesNotifier.pageSize,
    );
  }
}
