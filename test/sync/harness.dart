import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/sync/devices.dart';
import 'package:sentorr/sync/identity.dart';
import 'package:sentorr/sync/models.dart';
import 'package:sentorr/sync/pairing.dart';
import 'package:sentorr/sync/service.dart';

import '../support/fake_following.dart';
import '../support/fake_history.dart';
import '../support/fake_library.dart';
import '../support/fake_sync.dart';

/// One Sentorr on loopback holding [library], whose [downloads] are in the
/// queue, with nothing saved to disk.
Future<ProviderContainer> syncDevice(
  String name, {
  List<LibraryEntry> library = const [],
  List<DownloadItem> downloads = const [],
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      devicesRepositoryProvider.overrideWithValue(MemoryDevices()),
      initialDevicesProvider.overrideWithValue((
        identity: DeviceIdentity.generate(name),
        devices: const [],
      )),
      ...watchHistoryOverrides(),
      ...followedSeriesOverrides(),
      ...libraryOverrides(library),
      downloadsProvider.overrideWith((ref) => Stream.value(downloads)),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await container.read(syncServiceProvider).start();
  return container;
}

DeviceAddress addressOf(ProviderContainer c) =>
    (host: '127.0.0.1', port: c.read(syncServiceProvider).server.port);

String idOf(ProviderContainer c) => c.read(devicesProvider).identity.id;

Future<void> until(bool Function() done) async {
  for (var i = 0; i < 250 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(done(), true, reason: 'timed out');
}

/// Brings both devices to the code comparison, [host] waiting for [joiner].
Future<(PairingCompare, PairingCompare)> compareCodes(
  ProviderContainer host,
  ProviderContainer joiner,
) async {
  host.read(pairingProvider.notifier).open();
  await joiner.read(pairingProvider.notifier).join(addressOf(host));
  await until(
    () =>
        host.read(pairingProvider) is PairingCompare &&
        joiner.read(pairingProvider) is PairingCompare,
  );
  return (
    host.read(pairingProvider) as PairingCompare,
    joiner.read(pairingProvider) as PairingCompare,
  );
}

/// Pairs [host] and [joiner], both viewers confirming.
Future<void> pair(ProviderContainer host, ProviderContainer joiner) async {
  await compareCodes(host, joiner);
  await host.read(pairingProvider.notifier).decide(true);
  await joiner.read(pairingProvider.notifier).decide(true);
  await until(
    () =>
        host.read(pairingProvider) is PairingDone &&
        joiner.read(pairingProvider) is PairingDone,
  );
}
