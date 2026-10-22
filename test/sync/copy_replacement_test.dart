import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/sync/client.dart';
import 'package:sentorr/sync/copies.dart';
import 'package:sentorr/sync/copy_offer.dart';
import 'package:sentorr/sync/identity.dart';
import 'package:sentorr/sync/models.dart';
import 'package:sentorr/sync/payload.dart';
import 'package:sentorr/sync/peers.dart';
import 'package:sentorr/sync/service.dart';

import '../support/fake_sync.dart';
import '../support/fake_library.dart';
import '../support/fake_torrents.dart';

class GateClient extends PeerClient {
  GateClient(this.at) : super(DeviceIdentity.generate('Client'), port: () => 1);
  final Uri at;
  final transport = HttpClient();
  final entered = Completer<void>(), gate = Completer<void>();
  final gets = <String>[];
  @override
  Future<HttpClientResponse> open(
    DeviceAddress to,
    String fp,
    String path, {
    Map<String, dynamic>? body,
    String method = 'GET',
    Map<String, String> headers = const {},
    PeerRequest? cancellation,
  }) async {
    if (method == 'GET') {
      gets.add(headers[HttpHeaders.ifMatchHeader] ?? '');
      if (gets.length == 1) {
        entered.complete();
        await (cancellation?.wait(gate.future) ?? gate.future);
      }
    }
    final request = await transport.openUrl(method, at);
    headers.forEach(request.headers.set);
    return request.close();
  }

  @override
  void close() {
    transport.close(force: true);
    super.close();
  }
}

class Service extends SyncService {
  Service(super.ref, this.transport);
  final GateClient transport;
  @override
  PeerClient get client => transport;
}

void main() {
  test('canceled older copy cannot consume replacement copy', () async {
    final root = await Directory.systemTemp.createTemp(
      'sentorr-copy-generation-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final version = request.headers.value(HttpHeaders.ifMatchHeader)!;
      request.response.headers.set(HttpHeaders.etagHeader, version);
      request.response.contentLength = 4;
      if (request.method == 'GET') {
        request.response.add(List.filled(4, version == '"old"' ? 1 : 2));
      }
      await request.response.close();
    });
    final client = GateClient(Uri.http('127.0.0.1:${server.port}', '/media'));
    final identity = DeviceIdentity.generate('Source');
    final paired = PairedDevice(
      id: identity.id,
      name: identity.name,
      certificatePem: identity.certificatePem,
      pairedAt: DateTime.now(),
      address: (host: '127.0.0.1', port: server.port),
    );
    final c = ProviderContainer(
      overrides: [
        ...syncOverrides(devices: [paired]),
        ...libraryOverrides(),
        downloadsDirectoryProvider.overrideWithValue(root.path),
        peersProvider.overrideWith(() => FixedPeers({})),
        syncServiceProvider.overrideWith((ref) => Service(ref, client)),
      ],
    );
    final item = PlaybackItem(
      title: ImdbTitle(id: 'tt5', title: 'Movie'),
    );
    CopyOffer offer(bool old) => CopyOffer([
      (
        deviceId: identity.id,
        deviceName: identity.name,
        media: PeerMedia(
          item: item,
          size: 4,
          name: 'Movie.mkv',
          release: fakeRelease(old ? 1 : 2),
          fileIndex: 0,
          version: old ? 'old' : 'new',
        ),
      ),
    ]);
    try {
      final copies = c.read(peerCopiesProvider);
      copies.start(offer(true));
      await client.entered.future;
      await copies.cancel(item.id);
      copies.start(offer(false));
      // The replacement must finish without releasing the obsolete GET.
      for (var i = 0; i < 200 && c.read(libraryProvider).isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final entry = c.read(libraryProvider).single;
      expect(entry.release.infoHash, fakeRelease(2).infoHash);
      expect(await File(entry.path).readAsBytes(), [2, 2, 2, 2]);
      expect(client.gets, ['"old"', '"new"']);
      expect(c.read(copyingProvider), isEmpty);
    } finally {
      c.dispose();
      client.close();
      await server.close(force: true);
      await root.delete(recursive: true);
    }
  });
}
