import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/sync/client.dart';
import 'package:sentorr/sync/compatibility.dart';
import 'package:sentorr/sync/identity.dart';

void main() {
  test('fully consumed cancellable reads reuse their TLS connection', () async {
    final host = DeviceIdentity.generate('Host');
    final phone = DeviceIdentity.generate('Phone');
    final context = host.context()
      ..setTrustedCertificatesBytes(utf8.encode(phone.certificatePem));
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
      requestClientCertificate: true,
    );
    final ports = <int>{};
    server.listen((request) async {
      ports.add(request.connectionInfo!.remotePort);
      request.response.headers.set(
        compatibilityHeader,
        PeerCompatibility.current.header,
      );
      if (request.uri.path == '/v1/hello') {
        request.response.write(jsonEncode(PeerCompatibility.current.toJson()));
      } else {
        request.response.add([1, 2, 3]);
      }
      await request.response.close();
    });
    final client = PeerClient(phone, port: () => 47616);
    try {
      for (var i = 0; i < 3; i++) {
        final request = PeerRequest();
        final response = await client.open(
          (host: '127.0.0.1', port: server.port),
          host.fingerprint,
          '/v1/media/tt1',
          cancellation: request,
        );
        expect(
          await response.fold<List<int>>([], (all, data) => all..addAll(data)),
          [1, 2, 3],
        );
        request.complete();
      }
      expect(ports, hasLength(1));
      client.forget(host.fingerprint);
      final fresh = PeerRequest();
      final response = await client.open(
        (host: '127.0.0.1', port: server.port),
        host.fingerprint,
        '/v1/media/tt1',
        cancellation: fresh,
      );
      await response.drain<void>();
      fresh.complete();
      expect(ports, hasLength(2));
    } finally {
      client.close();
      await server.close(force: true);
    }
  });
}
