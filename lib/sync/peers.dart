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

final _log = Logger('sentorr.sync.peers');

/// How a paired device looks from here.
class PeerStatus {
  const PeerStatus({
    this.online = false,
    this.syncing = false,
    this.error,
    this.media = const [],
  });

  /// Answered its last request.
  final bool online;
  final bool syncing;

  /// Why it was last unreachable.
  final String? error;

  /// Its downloads this device can stream.
  final List<PeerMedia> media;

  PeerStatus copyWith({
    bool? online,
    bool? syncing,
    String? Function()? error,
    List<PeerMedia>? media,
  }) => PeerStatus(
    online: online ?? this.online,
    syncing: syncing ?? this.syncing,
    error: error == null ? this.error : error(),
    media: media ?? this.media,
  );
}

/// Paired devices by id: whether they are reachable and what they share.
/// Watch history and followed series sync with them soon after either
/// changes, when one is found, and every few minutes.
final peersProvider = NotifierProvider<PeersNotifier, Map<String, PeerStatus>>(
  PeersNotifier.new,
);

class PeersNotifier extends Notifier<Map<String, PeerStatus>> {
  /// Playback records progress every few seconds; one sync covers them.
  static const _settle = Duration(seconds: 10);
  static const _heartbeat = Duration(minutes: 3);

  Timer? _pending, _beat;

  /// Syncs under way by device, and those asked for again meanwhile.
  final _running = <String, Future<void>>{};
  final _again = <String>{};

  @override
  Map<String, PeerStatus> build() {
    ref.onDispose(() {
      _pending?.cancel();
      _beat?.cancel();
    });
    ref.listen(watchHistoryProvider, (_, _) => _schedule());
    ref.listen(followedSeriesProvider, (_, _) => _schedule());
    return const {};
  }

  /// Starts syncing on a timer, and with every paired device now.
  void start() {
    _beat ??= Timer.periodic(_heartbeat, (_) => unawaited(syncAll()));
    unawaited(syncAll());
  }

  void _schedule() {
    if (ref.read(devicesProvider).paired.isEmpty) return;
    _pending?.cancel();
    _pending = Timer(_settle, () => unawaited(syncAll()));
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
        body: _local().toJson(),
      );
      await _merge(SyncPayload.fromJson(answer));
      if (!ref.mounted) return;
      final library = await client.call(
        to.address,
        to.fingerprint,
        '/v1/library',
      );
      if (!ref.mounted) return;
      final media = library['media'];
      _set(
        id,
        (s) => PeerStatus(
          online: true,
          media: [if (media is List) ...media.map(PeerMedia.fromJson).nonNulls],
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
    return _local().toJson();
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

  SyncPayload _local() => SyncPayload(
    watch: ref.read(watchHistoryProvider.notifier).snapshot,
    following: ref.read(followedSeriesProvider.notifier).snapshot,
  );

  Future<void> _merge(SyncPayload incoming) async {
    await ref.read(watchHistoryProvider.notifier).merge(incoming.watch);
    await ref.read(followedSeriesProvider.notifier).merge(incoming.following);
  }

  void _set(String id, PeerStatus Function(PeerStatus) change) {
    if (!ref.mounted) return;
    state = {...state, id: change(state[id] ?? const PeerStatus())};
  }
}
