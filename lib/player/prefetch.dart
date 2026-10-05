import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/playback.dart';
import '../settings/notifier.dart';
import '../torrents/resolution_models.dart';
import '../torrents/providers.dart';
import '../watching/notifier.dart';
import 'models.dart';
import 'queue_builder.dart';
import 'session.dart';
import 'torrent_lookup.dart';

/// The Play target, including the episode/season rather than just series ID.
class PrefetchRequest {
  const PrefetchRequest(this.request);
  final PlayRequest request;
  (String, String?, int?) get key => switch (request) {
    PlayTitle(:final title, :final season) => (title.id, null, season),
    PlayEpisode(:final series, :final episode, :final season) => (
      series.id,
      episode.title.id,
      episode.seasonNumber ?? season,
    ),
  };
  @override
  bool operator ==(Object other) =>
      other is PrefetchRequest && key == other.key;
  @override
  int get hashCode => key.hashCode;
}

class PrefetchedLaunch {
  const PrefetchedLaunch(this.item, this.queue, this.resolution);
  final PlaybackItem item;
  final PlayQueue? queue;
  final TorrentResolution? resolution;
}

/// One page's search, detachable so Play can own an in-flight lookup.
class LaunchPrefetchEntry {
  LaunchPrefetchEntry(
    this.key,
    Future<PrefetchedLaunch> Function(CancelToken) run,
  ) {
    result = Future.sync(() => run(cancel));
    unawaited(result.then<void>((_) {}, onError: (Object _) {}));
  }
  final PrefetchRequest key;
  final cancel = CancelToken();
  late final Future<PrefetchedLaunch> result;
  bool taken = false;
}

class LaunchPrefetch {
  LaunchPrefetchEntry? _entry;
  LaunchPrefetchEntry start(
    PrefetchRequest key,
    Future<PrefetchedLaunch> Function(CancelToken) run,
  ) {
    final previous = _entry;
    if (previous != null &&
        previous.key == key &&
        !previous.cancel.isCancelled) {
      return previous;
    }
    clear();
    return _entry = LaunchPrefetchEntry(key, run);
  }

  LaunchPrefetchEntry? take(PlayRequest request) {
    final entry = _entry;
    if (entry == null ||
        entry.key != PrefetchRequest(request) ||
        entry.cancel.isCancelled) {
      return null;
    }
    _entry = null;
    entry.taken = true;
    return entry;
  }

  void release(LaunchPrefetchEntry entry) {
    if (entry.taken) return;
    entry.cancel.cancel();
    if (identical(entry, _entry)) _entry = null;
  }

  void clear() {
    _entry?.cancel.cancel();
    _entry = null;
  }
}

final launchPrefetchProvider = Provider<LaunchPrefetch>((ref) {
  final cache = LaunchPrefetch();
  ref.onDispose(cache.clear);
  return cache;
});

/// Watched only by a media detail page. No metadata/video is downloaded here.
final mediaTorrentPrefetchProvider = Provider.autoDispose
    .family<LaunchPrefetchEntry, PrefetchRequest>((ref, key) {
      ref.watch(settingsProvider.select((s) => (s.torrents, s.sources)));
      final cache = ref.read(launchPrefetchProvider);
      final entry = cache.start(key, (cancel) async {
        final builder = ref.read(queueBuilderProvider);
        final settings = ref.read(settingsProvider).torrents;
        final resolver = ref.read(torrentResolverProvider);
        final immediate = builder.immediate(key.request);
        final queue = immediate == null
            ? await builder.resolve(key.request, cancel)
            : null;
        if (cancel.isCancelled) throw cancel.cancelError!;
        final item = (queue ?? immediate!).current;
        if (ref.mounted &&
            (offlineSourceFor(ref, item) != null ||
                ref.read(watchHistoryProvider.notifier).savedRelease(item.id) !=
                    null)) {
          return PrefetchedLaunch(item, queue, null);
        }
        final resolution = await resolver.resolve(
          torrentQueryFor(item, languages: settings.languages),
          preferences: torrentPreferencesFor(settings),
          cancelToken: cancel,
        );
        return PrefetchedLaunch(item, queue, resolution);
      });
      ref.onDispose(() => cache.release(entry));
      return entry;
    });
