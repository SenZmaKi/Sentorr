import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../following/notifier.dart';
import '../lists/notifier.dart';
import '../player/models.dart';
import '../player/stream/offline_source.dart';
import '../watching/notifier.dart';
import 'client.dart';
import 'devices.dart';
import 'exchange.dart';
import 'media_proxy.dart';
import 'models.dart';
import 'payload.dart';
import 'peer_status.dart';

import 'peer_requests.dart';
import 'peer_source.dart';
import 'service.dart';
import 'shared_library.dart';
import 'state_exchange.dart';

export 'peer_status.dart';

final _log = Logger('sentorr.sync.peers');

/// Paired devices by id: whether they are reachable and what they share.
/// Watch history and followed series sync with them soon after either
/// changes, when one is found, and every few minutes. Each sync carries
/// both devices' libraries, so a download started, paused or finished on
/// one shows on the other within seconds; while a device has downloads
/// under way, their progress is fetched every few seconds.
final peersProvider = NotifierProvider<PeersNotifier, Map<String, PeerStatus>>(
  PeersNotifier.new,
);

class PeersNotifier extends Notifier<Map<String, PeerStatus>> {
  /// Playback records progress every few seconds; one sync covers them.
  static const _settle = Duration(seconds: 10);
  static const _heartbeat = Duration(minutes: 3);

  /// Soon enough for a download started on one device to show on another
  /// as it is looked at.
  static const _shared = Duration(seconds: 2);
  static const _progress = Duration(seconds: 5);

  Timer? _pending, _beat, _poll;
  DateTime? _deadline;
  final _requests = PeerRequests();

  bool _valid(String id, int epoch, String fingerprint) =>
      ref.mounted &&
      _requests.epoch(id) == epoch &&
      ref.read(devicesProvider).byId(id)?.fingerprint == fingerprint;

  /// Syncs under way by device, and those asked for again meanwhile.
  final _running = <String, Future<void>>{};
  final _again = <String>{};

  @override
  Map<String, PeerStatus> build() {
    ref.onDispose(() {
      _pending?.cancel();
      _beat?.cancel();
      _poll?.cancel();
    });
    ref.listen(watchHistoryProvider, (_, _) => _schedule(_settle));
    ref.listen(followedSeriesProvider, (_, _) => _schedule(_settle));
    ref.listen(watchListsProvider, (_, _) => _schedule(_settle));
    ref.listen(sharedLibraryShapeProvider, (_, _) => _schedule(_shared));
    return const {};
  }

  /// Starts syncing on a timer, and with every paired device now.
  void start() {
    _beat ??= Timer.periodic(_heartbeat, (_) => unawaited(syncAll()));
    _poll ??= Timer.periodic(_progress, (_) => _refreshDownloading());
    unawaited(syncAll());
  }

  /// The soonest of what is waiting wins, so a burst of changes is one sync.
  void _schedule(Duration after) {
    if (ref.read(devicesProvider).paired.isEmpty) return;
    final deadline = DateTime.now().add(after);
    if (_deadline != null && !_deadline!.isAfter(deadline)) return;
    _deadline = deadline;
    _pending?.cancel();
    _pending = Timer(after, () {
      _deadline = null;
      unawaited(syncAll());
    });
  }

  Future<void> syncAll() async {
    if (!ref.mounted) return;
    await Future.wait([
      for (final d in ref.read(devicesProvider).paired) syncWith(d.id),
    ]);
  }

  /// Where [id] is: found nearby, or where it was last reached.
  PeerRoute? route(String id) {
    final device = ref.read(devicesProvider).byId(id);
    final address =
        ref.read(syncServiceProvider).nearby[id]?.address ?? device?.address;
    if (device == null || address == null) return null;
    return (address: address, fingerprint: device.fingerprint);
  }

  /// Exchanges state with [id], then fetches what it shares. Asked while
  /// one runs, it runs once more after, so nothing changed meanwhile waits.
  Future<void> syncWith(String id) {
    if (_running[id] case final running?) {
      _again.add(id);
      return running;
    }
    final epoch = _requests.epoch(id);
    return _running[id] = _syncRepeatedly(id, epoch).whenComplete(() {
      // A block: returning the removed future would wait on itself.
      if (_requests.epoch(id) == epoch) _running.remove(id);
    });
  }

  Future<void> _syncRepeatedly(String id, int epoch) async {
    do {
      _again.remove(id);
      await _syncOnce(id);
    } while (_again.contains(id) &&
        ref.mounted &&
        _requests.epoch(id) == epoch);
  }

  Future<void> _syncOnce(String id) async {
    if (!ref.mounted) return;
    final to = route(id);
    if (to == null) return;
    final epoch = _requests.epoch(id);
    _requests.invalidateLibrary(id);
    final version = _requests.libraryVersion(id);
    _set(id, (s) => s.copyWith(syncing: true));
    final client = ref.read(syncServiceProvider).client;
    try {
      final payload = await localSyncPayload(ref);
      if (!_valid(id, epoch, to.fingerprint)) return;
      final answer = await client.call(
        to.address,
        to.fingerprint,
        '/v1/sync',
        body: payload,
      );
      if (!_valid(id, epoch, to.fingerprint)) return;
      // Decode the entire exchange before applying any of its records.
      final exchange = SyncExchange.decode(answer);
      final library = exchange.library;
      await mergePeerState(
        ref,
        exchange.state,
        () => _valid(id, epoch, to.fingerprint),
      );
      if (!_valid(id, epoch, to.fingerprint)) return;
      if (version != _requests.libraryVersion(id)) {
        _set(id, (s) => s.copyWith(syncing: false));
        return;
      }
      _set(
        id,
        (_) => PeerStatus(
          online: true,
          libraryRevision: library.revision,
          media: library.media,
          downloads: library.downloads,
        ),
      );
      await ref
          .read(devicesProvider.notifier)
          .update(
            id,
            (d) => d.copyWith(address: to.address, syncedAt: DateTime.now()),
          );
    } catch (error) {
      if (!_valid(id, epoch, to.fingerprint)) return;
      if (version != _requests.libraryVersion(id)) {
        _set(id, (s) => s.copyWith(syncing: false));
        return;
      }
      _log.fine('Sync with $id failed: $error');
      _set(
        id,
        (s) => PeerStatus(
          error: '$error',
          incompatible: error is PeerException && error.status == 426,
        ),
      );
    }
  }

  /// Answers a device that synced with this one: its state merged in, and
  /// this one's in return.
  Future<Map<String, dynamic>> answer(
    PairedDevice from,
    Map<String, dynamic> body,
  ) async {
    final epoch = _requests.epoch(from.id);
    bool valid() => _valid(from.id, epoch, from.fingerprint);
    if (!valid()) throw StateError('Device is no longer paired');
    _requests.invalidateLibrary(from.id);
    final version = _requests.libraryVersion(from.id);
    final exchange = SyncExchange.decode(body);
    final incomingLibrary = exchange.library;
    await mergePeerState(ref, exchange.state, valid);
    if (!valid()) throw StateError('Device is no longer paired');
    if (version == _requests.libraryVersion(from.id) &&
        body['library'] != null) {
      _set(
        from.id,
        (s) => s.copyWith(
          online: true,
          incompatible: false,
          error: () => null,
          library: incomingLibrary,
        ),
      );
    }
    final payload = await localSyncPayload(ref);
    if (!valid()) throw StateError('Device is no longer paired');
    return payload;
  }

  /// Fetches the libraries of devices with downloads under way, so their
  /// progress moves here too.
  void _refreshDownloading() {
    for (final MapEntry(key: id, value: peer) in state.entries) {
      if (peer.online && !peer.syncing && peer.downloads.isNotEmpty) {
        unawaited(refreshLibrary(id));
      }
    }
  }

  Future<void> refreshLibrary(String id) async {
    final to = route(id);
    if (to == null ||
        _running.containsKey(id) ||
        !_requests.refreshing.add(id)) {
      return;
    }
    final epoch = _requests.epoch(id), version = _requests.libraryVersion(id);
    bool valid() =>
        _valid(id, epoch, to.fingerprint) &&
        version == _requests.libraryVersion(id);
    try {
      final library = await ref
          .read(syncServiceProvider)
          .client
          .call(
            to.address,
            to.fingerprint,
            '/v1/library',
            headers: {
              'x-sentorr-library-revision': ?state[id]?.libraryRevision,
            },
          );
      // A sync that started meanwhile brings a newer one.
      if (!valid()) return;
      if (library['unchanged'] == true) {
        if (library['revision'] != state[id]?.libraryRevision) {
          throw StateError('Unrecognized library revision');
        }
      }
      final incoming = PeerLibrary.fromJson(library);
      final updated = library['unchanged'] == true
          ? PeerLibrary(
              media: state[id]!.media,
              downloads: incoming.downloads,
              revision: incoming.revision,
            )
          : incoming;
      _requests.invalidateLibrary(id);
      _set(
        id,
        (s) => s.copyWith(
          online: true,
          incompatible: false,
          error: () => null,
          library: updated,
        ),
      );
    } catch (error) {
      if (!valid()) return;
      _log.fine('Refreshing $id failed: $error');
      _set(
        id,
        (s) => PeerStatus(
          error: '$error',
          incompatible: error is PeerException && error.status == 426,
        ),
      );
    } finally {
      _requests.refreshing.remove(id);
    }
  }

  /// [device] reached this one from [address].
  void seen(PairedDevice device, DeviceAddress address) {
    if (device.address != address) {
      unawaited(
        ref
            .read(devicesProvider.notifier)
            .update(device.id, (d) => d.copyWith(address: address)),
      );
    }
    // Back after being away: fetch what it shares.
    if (state[device.id]?.online != true) {
      _set(
        device.id,
        (s) => s.copyWith(online: true, incompatible: false, error: () => null),
      );
      Timer.run(() => unawaited(syncWith(device.id)));
    }
  }

  /// A paired device was found nearby.
  void found(String id) {
    unawaited(syncWith(id));
  }

  void forget(String id) {
    _requests.forget(id);
    _running.remove(id);
    _again.remove(id);
    state = {...state}..remove(id);
  }

  void lost(String id) {
    _requests.invalidateLibrary(id);
    if (state.containsKey(id)) _set(id, (s) => s.copyWith(online: false));
  }

  /// [item] on a reachable paired device, streamed through the proxy.
  OfflineSource? sourceFor(PlaybackItem item) =>
      sharedPeerSource(ref, state, item);

  void _set(String id, PeerStatus Function(PeerStatus) change) {
    if (!ref.mounted) return;
    state = {...state, id: change(state[id] ?? const PeerStatus())};
  }
}
