import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../library/playback.dart';
import '../settings/notifier.dart';
import '../torrents/match.dart';
import '../torrents/models.dart';
import '../torrents/providers.dart';
import '../torrents/resolution_models.dart';
import '../watching/notifier.dart';
import 'models.dart';
import 'queue_builder.dart';
import 'session.dart';
import 'torrent_lookup.dart';

final _log = Logger('sentorr.launch');

/// Finding a torrent for what the viewer asked to play, before the player
/// opens. Searching until [resolution] or [error] arrives.
class PlaybackLaunch {
  const PlaybackLaunch({
    required this.request,
    required this.preferences,
    this.item,
    this.query,
    this.resolution,
    this.match,
    this.error,
  });

  final PlayRequest request;
  final TorrentPreferences preferences;

  /// What will play; null until known, e.g. a series' first episode.
  final PlaybackItem? item;

  /// The search as last run, including any title the viewer typed.
  final TorrentQuery? query;
  final TorrentResolution? resolution;

  /// The best candidate judged against [preferences]; null on a miss.
  final TorrentMatch? match;

  /// The item or search could not be prepared at all.
  final Object? error;

  bool get searching => resolution == null && error == null;
}

/// The launch in progress; null when nothing is being prepared.
final playbackLaunchProvider =
    NotifierProvider<PlaybackLaunchNotifier, PlaybackLaunch?>(
      PlaybackLaunchNotifier.new,
    );

class PlaybackLaunchNotifier extends Notifier<PlaybackLaunch?> {
  CancelToken? _cancel;

  /// The whole queue, when building it was needed to find the first item.
  PlayQueue? _prepared;

  @override
  PlaybackLaunch? build() {
    ref.onDispose(() => _cancel?.cancel());
    return null;
  }

  /// Finds a torrent for [request]. An exact match plays at once when the
  /// viewer has turned review off; anything else waits for [play].
  void start(PlayRequest request) {
    _log.info('Launching ${request.subject.title} (${request.subject.id})');
    final cancel = _restart();
    _prepared = null;
    state = PlaybackLaunch(
      request: request,
      preferences: torrentPreferencesFor(ref.read(settingsProvider).torrents),
    );
    _run(cancel, reuseSaved: true);
  }

  /// Searches again, optionally under another [title].
  void retry({String? title}) {
    final s = state;
    if (s == null) return;
    if (s.item == null) return start(s.request);
    final cancel = _restart();
    state = PlaybackLaunch(
      request: s.request,
      preferences: s.preferences,
      item: s.item,
      query: s.query,
    );
    final name = title?.trim();
    _log.info(
      'Retrying search for ${s.item}${name == null ? '' : ' as "$name"'}',
    );
    _run(cancel, title: name == null || name.isEmpty ? null : name);
  }

  /// Opens the player on the launch's item with [torrent].
  void play(TorrentCandidate torrent) {
    final s = state;
    if (s == null || s.item == null) return;
    final queue = _prepared;
    _log.info('Playing ${s.item} from ${torrent.release.name}');
    cancel();
    ref
        .read(playerSessionProvider.notifier)
        .play(s.request, queue: queue, torrent: torrent, options: s.resolution);
  }

  void cancel() {
    _restart();
    _prepared = null;
    state = null;
  }

  CancelToken _restart() {
    _cancel?.cancel();
    return _cancel = CancelToken();
  }

  Future<void> _run(
    CancelToken cancel, {
    String? title,
    bool reuseSaved = false,
  }) async {
    try {
      final item = state!.item ?? await _item(state!.request, cancel);
      if (cancel != _cancel) return;
      if (offlineSourceFor(ref, item) != null) {
        // Downloaded or downloading: the player uses that, no search.
        _log.info('Playing $item from its download');
        final queue = _prepared;
        final request = state!.request;
        this.cancel();
        ref.read(playerSessionProvider.notifier).play(request, queue: queue);
        return;
      }
      final saved = reuseSaved
          ? ref.read(watchHistoryProvider.notifier).savedRelease(item.id)
          : null;
      if (saved != null) {
        // Resuming: the torrent last streamed for it, no search.
        _log.info('Resuming $item from ${saved.name}');
        final queue = _prepared;
        final request = state!.request;
        this.cancel();
        ref
            .read(playerSessionProvider.notifier)
            .play(
              request,
              queue: queue,
              torrent: TorrentCandidate(
                release: saved,
                score: 0,
                qualityScore: 0,
                availabilityScore: 0,
                sizeScore: 0,
                requiresFileSelection: saved.isPack,
              ),
            );
        return;
      }
      final languages = ref.read(settingsProvider).torrents.languages;
      final query = torrentQueryFor(
        item,
        languages: languages,
        title: title ?? state!.query?.title,
      );
      final preferences = state!.preferences;
      state = PlaybackLaunch(
        request: state!.request,
        preferences: preferences,
        item: item,
        query: query,
      );
      final resolution = await ref
          .read(torrentResolverProvider)
          .resolve(query, preferences: preferences, cancelToken: cancel);
      if (cancel != _cancel) return;
      final match = TorrentMatch.of(resolution, preferences);
      _log.info(
        match == null
            ? 'No torrent found for $item'
            : '${match.exact ? 'Exact' : 'Close'} match for $item: '
                  '${match.candidate.release.name}'
                  '${match.concerns.isEmpty ? '' : ' (${match.concerns.map((c) => c.name).join(', ')})'}',
      );
      state = PlaybackLaunch(
        request: state!.request,
        preferences: preferences,
        item: item,
        query: query,
        resolution: resolution,
        match: match,
      );
      final review = ref.read(settingsProvider).torrents.reviewExactMatches;
      if (match != null && match.exact && !review) play(match.candidate);
    } catch (error, stack) {
      if (cancel != _cancel || _cancelled(error)) return;
      _log.warning('Could not find a torrent for ${state?.item}', error, stack);
      final s = state!;
      state = PlaybackLaunch(
        request: s.request,
        preferences: s.preferences,
        item: s.item,
        query: s.query,
        error: error,
      );
    }
  }

  /// The item [request] starts on, building the queue only when needed.
  Future<PlaybackItem> _item(PlayRequest request, CancelToken cancel) async {
    final builder = ref.read(queueBuilderProvider);
    final immediate = builder.immediate(request);
    if (immediate != null) return immediate.current;
    PlayQueue queue;
    try {
      queue = await builder.resolve(request, cancel);
    } catch (error) {
      // Offline, a series can still start on what is downloaded.
      final downloaded = _cancelled(error)
          ? null
          : downloadedQueue(ref, request);
      if (downloaded == null) rethrow;
      queue = downloaded;
    }
    _prepared = queue;
    return queue.current;
  }

  bool _cancelled(Object error) =>
      error is DioException && CancelToken.isCancel(error);
}
