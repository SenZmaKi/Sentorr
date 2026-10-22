import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentorr/sync/client.dart';
import 'package:sentorr/sync/devices.dart';
import 'package:sentorr/sync/identity.dart';
import 'package:sentorr/sync/models.dart';
import 'package:sentorr/sync/pairing.dart';
import 'package:sentorr/sync/service.dart';

import 'harness.dart';
import '../support/fake_sync.dart';

class FailDevices extends MemoryDevices {
  @override
  Future<void> save(DeviceIdentity identity, List<PairedDevice> devices) async {
    throw const FileSystemException('injected pairing save failure');
  }
}

void main() {
  test('concurrent durable pairing edits preserve every device', () async {
    final identity = DeviceIdentity.generate('Host');
    final repository = MemoryDevices();
    final container = ProviderContainer(
      overrides: [
        devicesRepositoryProvider.overrideWithValue(repository),
        initialDevicesProvider.overrideWithValue((
          identity: identity,
          devices: [],
        )),
      ],
    );
    addTearDown(container.dispose);
    PairedDevice peer(String name) {
      final identity = DeviceIdentity.generate(name);
      return PairedDevice(
        id: identity.id,
        name: name,
        certificatePem: identity.certificatePem,
        pairedAt: DateTime.now(),
      );
    }

    final a = peer('A'), b = peer('B');
    final notifier = container.read(devicesProvider.notifier);
    await Future.wait([
      notifier.add(a),
      notifier.add(b),
      notifier.rename('Renamed'),
    ]);
    expect(container.read(devicesProvider).paired.map((d) => d.id), [
      a.id,
      b.id,
    ]);
    expect(container.read(devicesProvider).identity.name, 'Renamed');
  });

  test('failed pairing persistence refuses authenticated access', () async {
    final host = await syncDevice('Host', devicesRepository: FailDevices());
    final joiner = await syncDevice('Joiner');
    try {
      await compareCodes(host, joiner);
      await host.read(pairingProvider.notifier).decide(true);
      await joiner.read(pairingProvider.notifier).decide(true);
      expect(host.read(pairingProvider), isA<PairingFailed>());
      expect(host.read(devicesProvider).byId(idOf(joiner)), isNull);
      final service = joiner.read(syncServiceProvider);
      await expectLater(
        service.client.open(
          addressOf(host),
          host.read(devicesProvider).identity.fingerprint,
          '/v1/library',
        ),
        throwsA(isA<PeerException>()),
      );
    } finally {
      await host.read(syncServiceProvider).close();
      await joiner.read(syncServiceProvider).close();
    }
  });
}
