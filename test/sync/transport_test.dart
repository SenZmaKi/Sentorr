import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/sync/client.dart';
import 'package:sentorr/sync/identity.dart';
import 'package:sentorr/sync/media_proxy.dart';
import 'package:sentorr/sync/models.dart';
import 'package:sentorr/sync/server.dart';

/// A host that knows one paired device and shares one file.
class _Routes implements SyncRoutes {
  _Routes(this.device, this.file);
  final PairedDevice device;
  final File file;
  final seenFrom = <DeviceAddress>[];

  @override
  PairedDevice? paired(String fingerprint) =>
      fingerprint == device.fingerprint ? device : null;

  @override
  void seen(PairedDevice device, DeviceAddress address) =>
      seenFrom.add(address);

  @override
  Future<Map<String, dynamic>> sync(
    PairedDevice device,
    Map<String, dynamic> body,
  ) async => {'echo': body['n']};

  @override
  Map<String, dynamic> library(PairedDevice device) => const {};

  @override
  File? media(PairedDevice device, String itemId) =>
      itemId == 'tt1' ? file : null;

  @override
  Future<Map<String, dynamic>> pairStart(Map<String, dynamic> body) async => {
    'hello': body['id'],
  };

  @override
  Future<Map<String, dynamic>> pairReveal(Map<String, dynamic> body) async =>
      const {};

  @override
  Future<Map<String, dynamic>> pairConfirm(
    Map<String, dynamic> body,
    DeviceAddress from,
  ) async => const {};
}

void main() {
  final host = DeviceIdentity.generate('Host');
  final phone = DeviceIdentity.generate('Phone');
  final stranger = DeviceIdentity.generate('Stranger');
  late SyncServer server;
  late _Routes routes;
  late DeviceAddress at;
  late Directory temp;
  final bytes = List.generate(300000, (i) => i % 251);

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('sentorr_sync');
    final file = File('${temp.path}/movie.mkv')..writeAsBytesSync(bytes);
    routes = _Routes(
      PairedDevice(
        id: phone.id,
        name: phone.name,
        certificatePem: phone.certificatePem,
        pairedAt: DateTime.now(),
      ),
      file,
    );
    server = SyncServer(host, routes);
    await server.start([phone.certificatePem]);
    at = (host: '127.0.0.1', port: server.port);
  });

  tearDownAll(() async {
    await server.close();
    await temp.delete(recursive: true);
  });

  test('a paired device syncs over its pinned certificate', () async {
    final client = PeerClient(phone, port: () => 4242);
    addTearDown(client.close);
    final answer = await client.call(
      at,
      host.fingerprint,
      '/v1/sync',
      body: {'n': 7},
    );
    expect(answer, {'echo': 7});
    expect(routes.seenFrom.last, (host: '127.0.0.1', port: 4242));
  });

  test('a device that is not paired is refused', () async {
    final client = PeerClient(stranger, port: () => 1);
    addTearDown(client.close);
    await expectLater(
      client.call(at, host.fingerprint, '/v1/sync', body: const {}),
      throwsA(isA<PeerException>()),
    );
  });

  test('a host presenting another certificate is not trusted', () async {
    final client = PeerClient(phone, port: () => 1);
    addTearDown(client.close);
    await expectLater(
      client.call(at, stranger.fingerprint, '/v1/sync', body: const {}),
      throwsA(isA<PeerException>()),
    );
  });

  test('pairing reports the certificate the host presented', () async {
    final client = PeerClient(stranger, port: () => 1);
    addTearDown(client.close);
    final answer = await client.pair(at, 'start', {'id': 'x'});
    expect(answer.body, {'hello': 'x'});
    expect(answer.fingerprint, host.fingerprint);
  });

  test('the proxy streams ranges of a shared file', () async {
    final client = PeerClient(phone, port: () => 1);
    final proxy = MediaProxy(
      client,
      (id) =>
          id == host.id ? (address: at, fingerprint: host.fingerprint) : null,
    );
    await proxy.start();
    final http = HttpClient();
    addTearDown(() async {
      http.close(force: true);
      await proxy.close();
      client.close();
    });

    final request = await http.getUrl(proxy.url(host.id, 'tt1')!);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=1000-1999');
    final response = await request.close();
    final body = await response.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(response.statusCode, HttpStatus.partialContent);
    expect(
      response.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 1000-1999/${bytes.length}',
    );
    expect(body, bytes.sublist(1000, 2000));

    final whole = await (await http.getUrl(proxy.url(host.id, 'tt1')!)).close();
    expect(
      (await whole.fold<List<int>>([], (a, b) => a..addAll(b))).length,
      bytes.length,
    );

    final missing = await (await http.getUrl(proxy.url(host.id, 'tt2')!))
        .close();
    await missing.drain<void>();
    expect(missing.statusCode, HttpStatus.notFound);
  });
}
