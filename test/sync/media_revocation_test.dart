import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/sync/client.dart';
import 'package:sentorr/sync/identity.dart';
import 'package:sentorr/sync/models.dart';
import 'package:sentorr/sync/server.dart';

class GatedFile implements File {
  GatedFile(this.real, {this.duringStat = false});
  final bool duringStat;
  final File real;
  final entered = Completer<void>(), gate = Completer<void>();
  @override
  String get path => real.path;
  @override
  File get absolute => real.absolute;
  @override
  Future<bool> exists() async {
    if (!duringStat) {
      if (!entered.isCompleted) entered.complete();
      await gate.future;
    }
    return real.exists();
  }

  @override
  Future<FileStat> stat() async {
    if (duringStat) {
      if (!entered.isCompleted) entered.complete();
      await gate.future;
    }
    return real.stat();
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      real.openRead(start, end);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Routes implements SyncRoutes {
  Routes(this.device, this.file);
  final PairedDevice device;
  final File file;
  bool allowed = true;
  @override
  PairedDevice? paired(String fp) =>
      allowed && fp == device.fingerprint ? device : null;
  @override
  void seen(PairedDevice device, DeviceAddress address) {}
  @override
  File? media(PairedDevice device, String id) => file;
  @override
  Map<String, dynamic> library(PairedDevice device) => {
    'revision': 'r',
    'media': [],
    'downloads': [],
  };
  @override
  Future<Map<String, dynamic>> sync(
    PairedDevice d,
    Map<String, dynamic> b,
  ) async => {};
  @override
  Future<Map<String, dynamic>> pairStart(Map<String, dynamic> b) async => {};
  @override
  Future<Map<String, dynamic>> pairReveal(Map<String, dynamic> b) async => {};
  @override
  Future<Map<String, dynamic>> pairConfirm(
    Map<String, dynamic> b,
    DeviceAddress a,
  ) async => {};
}

void main() {
  for (final duringStat in [false, true]) {
    test(
      'unpairing during file lookup revokes the request (stat: $duringStat)',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'sentorr-revoked-media-',
        );
        final file = GatedFile(
          await File('${root.path}/movie.mkv').writeAsString('private fixture'),
          duringStat: duringStat,
        );
        final host = DeviceIdentity.generate('Host'),
            peer = DeviceIdentity.generate('Peer');
        final routes = Routes(
          PairedDevice(
            id: peer.id,
            name: peer.name,
            certificatePem: peer.certificatePem,
            pairedAt: DateTime.now(),
          ),
          file,
        );
        final server = SyncServer(host, routes);
        await server.start([peer.certificatePem]);
        final client = PeerClient(peer, port: () => 1);
        final at = (host: '127.0.0.1', port: server.port);
        try {
          final pending = client.open(at, host.fingerprint, '/v1/media/tt1');
          await file.entered.future.timeout(const Duration(seconds: 5));
          routes.allowed = false;
          file.gate.complete();
          final response = await pending;
          expect(response.statusCode, HttpStatus.forbidden);
          final body = await response
              .transform(const SystemEncoding().decoder)
              .join();
          expect(body, isNot(contains('private fixture')));
        } finally {
          client.close();
          await server.close();
          await root.delete(recursive: true);
        }
      },
    );
  }
}
