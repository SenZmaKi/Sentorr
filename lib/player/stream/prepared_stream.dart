import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../torrents/models.dart';
import '../../torrents/resolution_models.dart';
import '../models.dart';
import 'file_choice.dart';
import 'parked_stream.dart';

/// A countdown's preparation, whose session can be handed to the player even
/// before metadata is ready. It never opens or creates a media player.
class PendingStream {
  PendingStream({
    required this.item,
    required this.candidate,
    required TorrentEngine engine,
    required Future<TorrentStreamConfig> Function(TorrentRelease) configFor,
    required Future<Uint8List> Function(TorrentRelease, CancelToken)
    fetchMetadata,
  }) {
    ready = _prepare(engine, configFor, fetchMetadata);
    unawaited(ready.then<void>((_) {}, onError: (Object _) {}));
  }
  final PlaybackItem item;
  final TorrentCandidate candidate;
  final cancel = CancelToken();
  late final Future<ParkedStream> ready;
  TorrentStreamSession? _session;
  Future<void>? _closed;

  Future<ParkedStream> _prepare(
    TorrentEngine engine,
    Future<TorrentStreamConfig> Function(TorrentRelease) configFor,
    Future<Uint8List> Function(TorrentRelease, CancelToken) fetchMetadata,
  ) async {
    final release = candidate.release;
    try {
      final values = await Future.wait<Object>([
        configFor(release),
        fetchMetadata(release, cancel),
        engine.start().then((_) => true),
      ]);
      if (cancel.isCancelled) throw cancel.cancelError!;
      final session = _session = TorrentStreamSession(
        engine: engine,
        config: values[0] as TorrentStreamConfig,
      );
      final files = await session.open(
        TorrentSource.metadata(
          values[1] as Uint8List,
          expectedInfoHash: release.infoHash,
          trackers: release.trackers,
        ),
      );
      if (cancel.isCancelled) throw cancel.cancelError!;
      final file = playableFile(
        files,
        item,
        pack: candidate.requiresFileSelection,
        seriesPack: release.isSeriesPack,
      );
      if (file == null) {
        throw StateError('No playable file in the prepared torrent');
      }
      final stream = await session.prepareFile(file.index);
      if (cancel.isCancelled) throw cancel.cancelError!;
      return ParkedStream(
        itemId: item.id,
        candidate: candidate,
        session: session,
        stream: stream,
      );
    } catch (_) {
      await close();
      rethrow;
    }
  }

  Future<void> close() {
    cancel.cancel();
    return _closed ??=
        _session?.close().catchError((Object _) {}) ?? Future.value();
  }
}

/// One launch at a time. A successful take transfers cancellation ownership
/// to playback; changing or cancelling a launch releases the pending session.
class PreparedStreams {
  PreparedStreams({required this.create});
  final PendingStream Function(PlaybackItem, TorrentCandidate) create;
  PendingStream? _pending;
  Timer? _expiry;

  TorrentCandidate? candidateFor(String itemId) =>
      _pending?.item.id == itemId ? _pending?.candidate : null;

  void start(
    PlaybackItem item,
    TorrentCandidate candidate, {
    Duration lifetime = const Duration(minutes: 1),
  }) {
    final previous = _pending;
    if (previous?.item.id == item.id &&
        previous?.candidate.release.infoHash == candidate.release.infoHash) {
      return;
    }
    clear();
    final pending = _pending = create(item, candidate);
    unawaited(
      pending.ready.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_pending, pending)) clear();
        },
      ),
    );
    // Also bound an unclaimed handoff if the player fails to mount.
    _expiry = Timer(lifetime, clear);
  }

  PendingStream? take(String itemId, String hash) {
    final pending = _pending;
    if (pending == null) return null;
    if (pending.item.id != itemId ||
        pending.candidate.release.infoHash != hash) {
      clear();
      return null;
    }
    _pending = null;
    _expiry?.cancel();
    return pending;
  }

  void clear() {
    _expiry?.cancel();
    final pending = _pending;
    _pending = null;
    if (pending != null) unawaited(pending.close());
  }
}
