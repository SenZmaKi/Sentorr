import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/sync/client.dart';
import 'package:sentorr/sync/identity.dart';
import 'package:sentorr/sync/media_proxy.dart';
import 'package:sentorr/sync/models.dart';
import 'package:sentorr/sync/server.dart';

class _Source implements SyncRoutes, BufferedSyncRoutes {
  _Source(this.device);
  final PairedDevice device;
  final released = Completer<void>();
  @override
  PairedDevice? paired(String fingerprint) =>
      fingerprint == device.fingerprint ? device : null;
  @override
  void seen(PairedDevice device, DeviceAddress address) {}
  @override
  Future<void> buffered(
    HttpRequest request,
    PairedDevice device,
    String itemId,
  ) async {
    final bytes = StreamController<List<int>>();
    final timer = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => bytes.add(List.filled(16384, 1)),
    );
    request.response.contentLength = 1000000000;
    try {
      await request.response.addStream(bytes.stream);
    } catch (_) {
      // The receiving player discarded its range to seek elsewhere.
    } finally {
      timer.cancel();
      unawaited(bytes.close());
      if (!released.isCompleted) released.complete();
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'discarding a player read releases its authenticated upstream request',
    () async {
      final host = DeviceIdentity.generate('Host');
      final phone = DeviceIdentity.generate('Phone');
      final routes = _Source(
        PairedDevice(
          id: phone.id,
          name: phone.name,
          certificatePem: phone.certificatePem,
          pairedAt: DateTime.now(),
        ),
      );
      final server = SyncServer(host, routes);
      await server.start([phone.certificatePem]);
      final client = PeerClient(phone, port: () => 47616);
      final proxy = MediaProxy(
        client,
        (_) => (
          address: (host: '127.0.0.1', port: server.port),
          fingerprint: host.fingerprint,
        ),
      );
      final http = HttpClient();
      try {
        await proxy.start();
        final url = proxy.url(
          host.id,
          'tt1',
          buffered: true,
          infoHash: '1' * 40,
        )!;
        final response = await (await http.getUrl(url)).close();
        await response.first;
        http.close(force: true);
        await routes.released.future.timeout(const Duration(seconds: 3));
      } finally {
        http.close(force: true);
        await proxy.close();
        client.close();
        await server.close();
      }
    },
  );
}
