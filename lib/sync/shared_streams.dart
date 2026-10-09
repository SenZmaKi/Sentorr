import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../player/models.dart';
import '../torrents/resolution_models.dart';
import 'payload.dart';

class SharedStream {
  const SharedStream(this.item, this.candidate, this.session, this.stream);
  final PlaybackItem item;
  final TorrentCandidate candidate;
  final TorrentStreamSession session;
  final TorrentStream stream;

  PeerMedia get offer => PeerMedia(
    item: item,
    size: stream.file.length,
    name: stream.file.path.split('/').last,
    release: candidate.release,
    fileIndex: stream.file.index,
    bufferedBytes: session.state.selectedBytes,
  );
}

final sharedStreamsProvider =
    NotifierProvider<SharedStreamsNotifier, Map<String, SharedStream>>(
      SharedStreamsNotifier.new,
    );

/// Active and parked sessions already backed by verified torrent storage.
class SharedStreamsNotifier extends Notifier<Map<String, SharedStream>> {
  final _subscriptions = <String, StreamSubscription<TorrentStreamState>>{};
  @override
  Map<String, SharedStream> build() {
    ref.onDispose(() {
      for (final subscription in _subscriptions.values) {
        unawaited(subscription.cancel());
      }
    });
    return const {};
  }

  void register(SharedStream stream) {
    final id = stream.item.id;
    unawaited(_subscriptions.remove(id)?.cancel());
    state = {...state, id: stream};
    _subscriptions[id] = stream.session.states.listen((snapshot) {
      if (!ref.mounted || !identical(state[id], stream)) return;
      if (snapshot.phase == TorrentStreamPhase.closed ||
          snapshot.phase == TorrentStreamPhase.failed) {
        state = {...state}..remove(id);
        unawaited(_subscriptions.remove(id)?.cancel());
      } else {
        state = {...state};
      }
    });
  }
}

/// A peer has its own owner, keeping storage alive when local playback closes.
class BufferedStreamLease {
  BufferedStreamLease(SharedStream source)
    : session = TorrentStreamSession(
        engine: source.session.engine,
        config: source.session.config,
      ) {
    ready = _open(source);
    unawaited(ready.then<void>((_) {}, onError: (Object _) {}));
  }
  final TorrentStreamSession session;
  late final Future<Uri> ready;
  Timer? _idle;
  int _readers = 0;
  bool _closed = false;

  Future<Uri> _open(SharedStream source) async {
    try {
      await session.open(TorrentSource.magnet(source.candidate.release.magnet));
      final stream = await session.prepareFile(source.stream.file.index);
      return stream.uri;
    } catch (_) {
      await close();
      rethrow;
    }
  }

  void acquire() {
    if (_closed) throw StateError('Buffered stream expired');
    _idle?.cancel();
    _readers++;
  }

  void release(void Function() expire) {
    _readers--;
    if (_readers == 0 && !_closed) {
      _idle = Timer(const Duration(minutes: 5), expire);
    }
  }

  Future<void> close() async {
    _closed = true;
    _idle?.cancel();
    await session.close();
  }
}
