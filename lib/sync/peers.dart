import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../following/notifier.dart';
import '../player/models.dart';
import '../player/stream/offline_source.dart';
import '../watching/notifier.dart';
import 'devices.dart';
import 'media_proxy.dart';
import 'models.dart';
import 'payload.dart';
import 'service.dart';
import 'shared_library.dart';

final _log = Logger('sentorr.sync.peers');

/// How a paired device looks from here.
class PeerStatus {
  const PeerStatus({
    this.online = false,
    this.syncing = false,
    this.error,
    this.media = const [],
    this.downloads = const [],
  });

  /// Answered its last request.
  final bool online;
  final bool syncing;

  /// Why it was last unreachable.
  final String? error;

  /// Its finished downloads this device can stream or copy.
  final List<PeerMedia> media;

  /// Its downloads still on their way.
  final List<PeerDownload> downloads;

  PeerStatus copyWith({
    bool? online,
    bool? syncing,
    String? Function()? error,
    PeerLibrary? library,
  }) => PeerStatus(
    online: online ?? this.online,
    syncing: syncing ?? this.syncing,
    error: error == null ? this.error : error(),
    media: library?.media ?? media,
    downloads: library?.downloads ?? downloads,
  );
}

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
    _pending?.cancel();
    _pending = Timer(after, () => unawaited(syncAll()));
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
    return _running[id] = _syncRepeatedly(id).whenComplete(() {
      // A block: returning the removed future would wait on itself.
      _running.remove(id);
    });
  }

  Future<void> _syncRepeatedly(String id) async {
    do {
      _again.remove(id);
      await _syncOnce(id);
    } while (_again.contains(id) && ref.mounted);
  }

  Future<void> _syncOnce(String id) async {
    if (!ref.mounted) return;
    final to = route(id);
    if (to == null) return;
    _set(id, (s) => s.copyWith(syncing: true));
    final client = ref.read(syncServiceProvider).client;
    try {
      final answer = await client.call(
        to.address,
        to.fingerprint,
        '/v1/sync',
        body: _local(),
      );
      await _merge(SyncPayload.fromJson(answer));
      if (!ref.mounted) return;
      // Devices from before libraries rode along answer without one.
      final library = PeerLibrary.fromJson(
        answer['library'] ??
            await client.call(to.address, to.fingerprint, '/v1/library'),
      );
      if (!ref.mounted) return;
      _set(
        id,
        (_) => PeerStatus(
          online: true,
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
      _log.fine('Sync with $id failed: $error');
      _set(id, (s) => PeerStatus(error: '$error'));
    }
  }

  /// Answers a device that synced with this one: its state merged in, and
  /// this one's in return.
  Future<Map<String, dynamic>> answer(
    PairedDevice from,
    Map<String, dynamic> body,
  ) async {
    await _merge(SyncPayload.fromJson(body));
    if (body['library'] case final library?) {
      _set(
        from.id,
        (s) => s.copyWith(
          online: true,
          error: () => null,
          library: PeerLibrary.fromJson(library),
        ),
      );
    }
    return _local();
  }

  /// Fetches the libraries of devices with downloads under way, so their
  /// progress moves here too.
  void _refreshDownloading() {
    for (final MapEntry(key: id, value: peer) in state.entries) {
      if (peer.online && !peer.syncing && peer.downloads.isNotEmpty) {
        unawaited(_refresh(id));
      }
    }
  }

  Future<void> _refresh(String id) async {
    final to = route(id);
    if (to == null || _running.containsKey(id)) return;
    try {
      final library = await ref
          .read(syncServiceProvider)
          .client
          .call(to.address, to.fingerprint, '/v1/library');
      // A sync that started meanwhile brings a newer one.
      if (_running.containsKey(id)) return;
      _set(id, (s) => s.copyWith(library: PeerLibrary.fromJson(library)));
    } catch (error) {
      _log.fine('Refreshing $id failed: $error');
      _set(id, (s) => PeerStatus(error: '$error'));
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
      _set(device.id, (s) => s.copyWith(online: true, error: () => null));
      Timer.run(() => unawaited(syncWith(device.id)));
    }
  }

  /// A paired device was found nearby.
  void found(String id) {
    if (state[id]?.online != true) unawaited(syncWith(id));
  }

  void forget(String id) => state = {...state}..remove(id);

  /// [item] on a reachable paired device, streamed through the proxy.
  OfflineSource? sourceFor(PlaybackItem item) {
    final devices = ref.read(devicesProvider);
    for (final MapEntry(key: id, value: peer) in state.entries) {
      if (!peer.online || !peer.media.any((m) => m.id == item.id)) continue;
      final url = ref.read(syncServiceProvider).proxy.url(id, item.id);
      final name = devices.byId(id)?.name;
      if (url != null && name != null) return PeerFile(url, name);
    }
    return null;
  }

  Map<String, dynamic> _local() => {
    ...SyncPayload(
      watch: ref.read(watchHistoryProvider.notifier).snapshot,
      following: ref.read(followedSeriesProvider.notifier).snapshot,
    ).toJson(),
    'library': sharedLibrary(ref).toJson(),
  };

  Future<void> _merge(SyncPayload incoming) async {
    await ref.read(watchHistoryProvider.notifier).merge(incoming.watch);
    await ref.read(followedSeriesProvider.notifier).merge(incoming.following);
  }

  void _set(String id, PeerStatus Function(PeerStatus) change) {
    if (!ref.mounted) return;
    state = {...state, id: change(state[id] ?? const PeerStatus())};
  }
}
