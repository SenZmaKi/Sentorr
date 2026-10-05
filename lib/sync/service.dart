import 'dart:async';
import 'dart:io';

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
class SyncService implements SyncRoutes {
  SyncService(this._ref);
  final Ref _ref;

  late final SyncServer server = SyncServer(_identity, this);
  late final PeerClient client = PeerClient(_identity, port: () => server.port);
  late final MediaProxy proxy = MediaProxy(
    client,
    (id) => _ref.read(peersProvider.notifier).route(id),
  );
  LocalDiscovery? _discovery;
  bool _started = false;

  DeviceIdentity get _identity => _ref.read(devicesProvider).identity;

  Map<String, NearbyDevice> get nearby => _discovery?.nearby ?? const {};

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await server.start([
        for (final d in _ref.read(devicesProvider).paired) d.certificatePem,
      ]);
      await proxy.start();
    } on SocketException catch (error, stack) {
      _log.warning('Device sync unavailable', error, stack);
      return;
    }
    final discovery = _discovery = LocalDiscovery(
      identity: _identity,
      port: server.port,
      onChanged: _onNearby,
    );
    _ref.listen(devicesProvider.select((s) => s.identity), (_, renamed) {
      unawaited(discovery.rename(renamed));
    });
    unawaited(discovery.start());
    _ref.read(peersProvider.notifier).start();
  }

  void _onNearby(Map<String, NearbyDevice> found) {
    final before = _ref.read(nearbyDevicesProvider);
    _ref.read(nearbyDevicesProvider.notifier).set(found);
    final paired = _ref.read(devicesProvider);
    for (final id in found.keys) {
      if (!before.containsKey(id) && paired.byId(id) != null) {
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
  Map<String, dynamic> library(PairedDevice device) =>
      sharedLibrary(_ref).toJson();

  @override
  File? media(PairedDevice device, String itemId) => sharedFile(_ref, itemId);

  Future<void> close() async {
    // Its parts are made on first use; a service never started has none.
    if (!_started) return;
    await _discovery?.stop();
    await server.close();
    await proxy.close();
    client.close();
  }
}
