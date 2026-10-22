import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/sync/devices.dart';
import 'package:sentorr/sync/identity.dart';
import 'package:sentorr/sync/server.dart';
import 'package:sentorr/sync/service.dart';

import '../support/fake_sync.dart';

class _GatedServer extends SyncServer {
  _GatedServer(super.identity, super.routes);
  final entered = Completer<void>(), release = Completer<void>();
  int boundPort = 0, closes = 0;
  @override
  Future<void> start(Iterable<String> trusted) async {
    entered.complete();
    await release.future;
    await super.start(trusted);
    boundPort = port;
  }

  @override
  Future<void> close() async {
    closes++;
    await super.close();
  }
}

class _Service extends SyncService {
  _Service(super.ref, DeviceIdentity identity) {
    _server = _GatedServer(identity, this);
  }
  late final _GatedServer _server;
  @override
  _GatedServer get server => _server;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'close drains an outstanding bind and is idempotent after disposal',
    () async {
      final identity = DeviceIdentity.generate('lifecycle fixture');
      final container = ProviderContainer(
        overrides: [
          devicesRepositoryProvider.overrideWithValue(MemoryDevices()),
          initialDevicesProvider.overrideWithValue((
            identity: identity,
            devices: [],
          )),
          syncServiceProvider.overrideWith((ref) {
            final service = _Service(ref, identity);
            ref.onDispose(service.close);
            return service;
          }),
        ],
      );
      final service = container.read(syncServiceProvider) as _Service;
      final starting = service.start();
      expect(identical(starting, service.start()), isTrue);
      await service.server.entered.future;
      final closing = service.close();
      expect(identical(closing, service.close()), isTrue);
      container.dispose();
      service.server.release.complete();
      await Future.wait([starting, closing]);
      expect(service.server.closes, 1);
      expect(service.server.boundPort, greaterThan(0));
      await expectLater(
        Socket.connect('127.0.0.1', service.server.boundPort),
        throwsA(isA<SocketException>()),
      );
      await service.start();
      expect(service.server.closes, 1);
    },
  );
}
