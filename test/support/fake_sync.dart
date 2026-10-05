import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/sync/devices.dart';
import 'package:sentorr/sync/identity.dart';
import 'package:sentorr/sync/models.dart';
import 'package:sentorr/sync/payload.dart';
import 'package:sentorr/sync/peers.dart';
import 'package:sentorr/sync/repository.dart';

/// Saves nothing; nothing touches disk.
class MemoryDevices extends DevicesRepository {
  MemoryDevices() : super(JsonFileStore(File('unused')));

  @override
  Future<void> save(
    DeviceIdentity identity,
    List<PairedDevice> devices,
  ) async {}
}

/// Generated once: making a certificate takes a moment.
final _identity = DeviceIdentity.generate('Test device');

/// Overrides for a device paired with [devices], named [name].
List<Override> syncOverrides({
  String name = 'Test device',
  List<PairedDevice> devices = const [],
}) => [
  devicesRepositoryProvider.overrideWithValue(MemoryDevices()),
  initialDevicesProvider.overrideWithValue((
    identity: _identity.named(name),
    devices: devices,
  )),
];

/// Paired devices that are online and share [peers] media, without a
/// network.
class FixedPeers extends PeersNotifier {
  FixedPeers(this.peers);
  final Map<String, PeerStatus> peers;

  @override
  Map<String, PeerStatus> build() => peers;
}

/// A device named [name], paired, online and sharing [media].
({PairedDevice device, Override peers}) onlinePeer(
  String name,
  List<PeerMedia> media,
) {
  final identity = DeviceIdentity.generate(name);
  return (
    device: PairedDevice(
      id: identity.id,
      name: name,
      certificatePem: identity.certificatePem,
      pairedAt: DateTime(2026),
    ),
    peers: peersProvider.overrideWith(
      () => FixedPeers({identity.id: PeerStatus(online: true, media: media)}),
    ),
  );
}
