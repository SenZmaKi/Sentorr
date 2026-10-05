import '../shared/persistence/json_file_store.dart';
import 'identity.dart';
import 'models.dart';

/// This device's identity and the devices it is paired with.
class DevicesRepository {
  DevicesRepository(this.store);
  final JsonFileStore store;

  /// The saved identity, or a new one saved now.
  Future<({DeviceIdentity identity, List<PairedDevice> devices})> load() async {
    final json = await store.read();
    final saved = DeviceIdentity.fromJson(json?['identity']);
    final devices = json?['devices'];
    final paired = [
      if (devices is List) ...devices.map(PairedDevice.fromJson).nonNulls,
    ];
    final identity = saved ?? DeviceIdentity.generate(defaultDeviceName());
    if (saved == null) await save(identity, paired);
    return (identity: identity, devices: paired);
  }

  Future<void> save(DeviceIdentity identity, List<PairedDevice> devices) =>
      store.write({
        'version': 1,
        'identity': identity.toJson(),
        'devices': [for (final d in devices) d.toJson()],
      });
}
