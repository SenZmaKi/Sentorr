import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'identity.dart';
import 'models.dart';
import 'repository.dart';

final _log = Logger('sentorr.sync.devices');

final devicesRepositoryProvider = Provider<DevicesRepository>(
  (ref) =>
      throw StateError('Bootstrap must override devicesRepositoryProvider'),
);
final initialDevicesProvider =
    Provider<({DeviceIdentity identity, List<PairedDevice> devices})>(
      (ref) =>
          throw StateError('Bootstrap must override initialDevicesProvider'),
    );

class DevicesState {
  const DevicesState(this.identity, this.paired);

  /// This device.
  final DeviceIdentity identity;

  /// The devices it syncs with, in pairing order.
  final List<PairedDevice> paired;

  PairedDevice? byId(String id) => paired.where((d) => d.id == id).firstOrNull;

  PairedDevice? byFingerprint(String fingerprint) =>
      paired.where((d) => d.fingerprint == fingerprint).firstOrNull;
}

/// This device's identity and the devices paired with it, saved as they
/// change.
final devicesProvider = NotifierProvider<DevicesNotifier, DevicesState>(
  DevicesNotifier.new,
);

class DevicesNotifier extends Notifier<DevicesState> {
  late DevicesRepository _repository;

  @override
  DevicesState build() {
    _repository = ref.watch(devicesRepositoryProvider);
    final initial = ref.watch(initialDevicesProvider);
    return DevicesState(initial.identity, initial.devices);
  }

  Future<void> rename(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == state.identity.name) {
      return Future.value();
    }
    return _commit(DevicesState(state.identity.named(trimmed), state.paired));
  }

  /// Saves [device], replacing an earlier pairing with it.
  Future<void> add(PairedDevice device) {
    _log.info('Paired with ${device.name} (${device.id})');
    return _commit(
      DevicesState(state.identity, [
        for (final d in state.paired)
          if (d.id != device.id) d,
        device,
      ]),
    );
  }

  Future<void> remove(String id) {
    _log.info('Unpaired $id');
    return _commit(
      DevicesState(state.identity, [
        for (final d in state.paired)
          if (d.id != id) d,
      ]),
    );
  }

  /// Changes [id]'s record; nothing when it is not paired or unchanged.
  Future<void> update(String id, PairedDevice Function(PairedDevice) change) {
    final device = state.byId(id);
    if (device == null) return Future.value();
    final next = change(device);
    if (next.toJson().toString() == device.toJson().toString()) {
      return Future.value();
    }
    return _commit(
      DevicesState(state.identity, [
        for (final d in state.paired) d.id == id ? next : d,
      ]),
    );
  }

  Future<void> _commit(DevicesState next) {
    if (ref.mounted) state = next;
    return _repository.save(next.identity, next.paired);
  }
}
