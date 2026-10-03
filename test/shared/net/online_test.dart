import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/shared/net/net.dart';
import 'package:sentorr/shared/net/online.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The binding answers every request with 400; these need real sockets.
  HttpOverrides.global = null;

  test('is assumed online and follows each check', () async {
    var reachable = false;
    final container = ProviderContainer(
      overrides: [
        internetProbeProvider.overrideWithValue(() async => reachable),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(onlineProvider), isTrue);
    await container.read(onlineProvider.notifier).check();
    expect(container.read(onlineProvider), isFalse);

    reachable = true;
    await container.read(onlineProvider.notifier).check();
    expect(container.read(onlineProvider), isTrue);
  });

  test('a request that gets no answer prompts a check', () async {
    var probes = 0;
    final network = NetworkClient(http2: false, logging: false);
    addTearDown(network.close);
    final container = ProviderContainer(
      overrides: [
        networkFailuresProvider.overrideWithValue(network.networkFailures),
        internetProbeProvider.overrideWithValue(() async {
          probes++;
          return false;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(onlineProvider);
    expect(probes, 0);

    // Nothing listens on port 9 of this machine.
    await expectLater(
      network.dio.get<void>('http://127.0.0.1:9/'),
      throwsA(anything),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(probes, 1);
    expect(container.read(onlineProvider), isFalse);
  });
}
