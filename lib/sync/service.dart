import 'dart:async';
import 'dart:io';

import '../shared/cleanup.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'client.dart';
import 'devices.dart';
import 'discovery.dart';
import 'identity.dart';
import 'media_proxy.dart';
import 'models.dart';
import 'pairing.dart';
import 'peers.dart';
import 'server.dart';
import 'shared_library.dart';
import 'shared_streams.dart';
import 'buffered_media.dart';

final _log = Logger('sentorr.sync');

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(service.close);
  return service;
});

/// Sentorrs found on the local network, by device id.
final nearbyDevicesProvider =
    NotifierProvider<NearbyDevicesNotifier, Map<String, NearbyDevice>>(
      NearbyDevicesNotifier.new,
    );

class NearbyDevicesNotifier extends Notifier<Map<String, NearbyDevice>> {
  @override
  Map<String, NearbyDevice> build() => const {};

  void set(Map<String, NearbyDevice> nearby) => state = nearby;
}

/// The device's place on the local network: the HTTPS server paired
/// devices sync and stream from, the client that reaches theirs, mDNS, and
/// the loopback proxy the player streams their files through.
class SyncService implements SyncRoutes, BufferedSyncRoutes {
  SyncService(this._ref);
  final Ref _ref;

  late final SyncServer server = SyncServer(_identity, this);
  late final PeerClient client = PeerClient(_identity, port: () => server.port);
  late final MediaProxy proxy = MediaProxy(
    client,
    (id) => _ref.read(peersProvider.notifier).route(id),
  );
  late final _buffered = BufferedMedia(
    (id) => _ref.read(sharedStreamsProvider)[id],
  );
  LocalDiscovery? _discovery;
  bool _started = false;
  bool _closing = false;
  Future<void>? _starting, _closed;

  DeviceIdentity get _identity => _ref.read(devicesProvider).identity;

  Map<String, NearbyDevice> get nearby => _discovery?.nearby ?? const {};

  Future<void> start() {
    if (_closing) return Future.value();
    return _starting ??= _start();
  }

  Future<void> _start() async {
    _started = true;
    // Capture provider-backed identity before the first await. A container
    // disposal may begin while the operating system is still binding ports.
    final serving = server;
    final forwarding = proxy;
    try {
      await serving.start([
        for (final d in _ref.read(devicesProvider).paired) d.certificatePem,
      ]);
      if (_closing || !_ref.mounted) return;
      await forwarding.start();
    } on SocketException catch (error, stack) {
      _log.warning('Device sync unavailable', error, stack);
      return;
    }
    if (_closing || !_ref.mounted) return;
    final discovery = _discovery = LocalDiscovery(
      identity: _identity,
      port: server.port,
      onChanged: _onNearby,
    );
    _ref.listen(devicesProvider.select((s) => s.identity), (_, renamed) {
      if (!_closing) unawaited(discovery.rename(renamed));
    });
    await discovery.start();
    if (!_closing && _ref.mounted) _ref.read(peersProvider.notifier).start();
  }

  void _onNearby(Map<String, NearbyDevice> found) {
    if (_closing || !_ref.mounted) return;
    final before = _ref.read(nearbyDevicesProvider);
    _ref.read(nearbyDevicesProvider.notifier).set(found);
    final paired = _ref.read(devicesProvider);
    for (final id in before.keys) {
      if (!found.containsKey(id)) _ref.read(peersProvider.notifier).lost(id);
    }
    for (final id in found.keys) {
      if (before[id]?.address != found[id]?.address &&
          paired.byId(id) != null) {
        _ref.read(peersProvider.notifier).found(id);
      }
    }
  }

  Future<void> setPairing(bool open) =>
      _discovery?.setPairing(open) ?? Future.value();

  /// Trusts [device] from now on and syncs with it.
  Future<void> addPaired(PairedDevice device) async {
    server.trust(device.certificatePem);
    await _ref.read(devicesProvider.notifier).add(device);
    unawaited(_ref.read(peersProvider.notifier).syncWith(device.id));
  }

  /// Stops syncing with [id]; its certificate is refused from now on.
  Future<void> unpair(String id) async {
    final device = _ref.read(devicesProvider).byId(id);
    if (device == null) return;
    client.forget(device.fingerprint);
    _ref.read(peersProvider.notifier).forget(id);
    await _ref.read(devicesProvider.notifier).remove(id);
  }

  @override
  Future<Map<String, dynamic>> pairStart(Map<String, dynamic> body) =>
      _ref.read(pairingProvider.notifier).hostStart(body);

  @override
  Future<Map<String, dynamic>> pairReveal(Map<String, dynamic> body) =>
      _ref.read(pairingProvider.notifier).hostReveal(body);

  @override
  Future<Map<String, dynamic>> pairConfirm(
    Map<String, dynamic> body,
    DeviceAddress from,
  ) => _ref.read(pairingProvider.notifier).hostConfirm(body, from);

  @override
  PairedDevice? paired(String fingerprint) =>
      _ref.read(devicesProvider).byFingerprint(fingerprint);

  @override
  void seen(PairedDevice device, DeviceAddress address) =>
      _ref.read(peersProvider.notifier).seen(device, address);

  @override
  Future<Map<String, dynamic>> sync(
    PairedDevice device,
    Map<String, dynamic> body,
  ) => _ref.read(peersProvider.notifier).answer(device, body);

  @override
  Future<Map<String, dynamic>> library(PairedDevice device) async =>
      (await sharedLibrary(_ref)).toJson();

  @override
  File? media(PairedDevice device, String itemId) => sharedFile(_ref, itemId);

  @override
  Future<void> buffered(
    HttpRequest request,
    PairedDevice device,
    String itemId,
  ) => _buffered.serve(request, itemId);

  Future<void> close() {
    _closing = true;
    return _closed ??= _close();
  }

  Future<void> _close() async {
    if (!_started) return;
    // A bind/discovery operation may complete after close was requested.
    // Drain it before closing its resources, including on provider disposal.
    await cleanupAll([
      () async => _starting,
      () async => _discovery?.stop(),
      server.close,
      proxy.close,
      _buffered.close,
      client.close,
    ]);
  }
}
