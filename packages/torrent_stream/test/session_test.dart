import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:test/test.dart';
import 'package:torrent_stream/torrent_stream.dart';

Future<Uint8List> range(HttpClient client, Uri uri, int start, int end) async {
  final request = await client.getUrl(uri);
  request.headers.set('Range', 'bytes=$start-$end');
  final response = await request.close();
  expect(response.statusCode, 206);
  expect(response.headers.value('content-range'), 'bytes $start-$end/8388731');
  final builder = BytesBuilder();
  await for (final chunk in response) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

void main() {
  test(
    'public endpoint: exact ranges, paused seed recovery, seek cleanup and owned cache cleanup',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'torrent-stream-contract-',
      );
      final cache = await Directory('${root.path}/cache').create();
      final sentinel = await File(
        '${cache.path}/caller-owned.txt',
      ).writeAsString('preserve');
      final seedRoot = await Directory('${root.path}/seed').create();
      final fixture = Uint8List(8 * 1024 * 1024 + 123);
      for (var i = 0; i < fixture.length; i++) {
        fixture[i] = (i * 17 + 3) % 251;
      }
      final source = await File(
        '${seedRoot.path}/fixture.bin',
      ).writeAsBytes(fixture);
      final metadata = createTorrentData(
        sourcePath: source.path,
        pieceSize: 128 * 1024,
      );
      final native = createSessionFromTags([
        LibtorrentTagItem.settingsBool(
          LibtorrentSettingsTag.closeRedundantConnections,
          false,
        ),
        LibtorrentTagItem.settingsString(
          LibtorrentSettingsTag.listenInterfaces,
          '127.0.0.1:0',
        ),
        LibtorrentTagItem.settingsBool(LibtorrentSettingsTag.enableDht, false),
        LibtorrentTagItem.settingsBool(LibtorrentSettingsTag.enableUpnp, false),
        LibtorrentTagItem.settingsBool(
          LibtorrentSettingsTag.enableNatpmp,
          false,
        ),
        LibtorrentTagItem.settingsBool(LibtorrentSettingsTag.enableLsd, false),
        LibtorrentTagItem.settingsBool(
          LibtorrentSettingsTag.enableOutgoingUtp,
          false,
        ),
        LibtorrentTagItem.settingsBool(
          LibtorrentSettingsTag.enableIncomingUtp,
          false,
        ),
      ]);
      final seed = native.addTorrentData(
        torrentData: metadata,
        savePath: seedRoot.path,
      );
      seed.unsetFlags(
        LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
      );
      final watch = Stopwatch()..start();
      while (seed.getStatus().state != 5 || native.listenPort == 0) {
        if (watch.elapsed > const Duration(seconds: 10)) {
          throw StateError('Seed not ready');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final peer = TorrentPeer('127.0.0.1', native.listenPort);
      final session = TorrentStreamSession(
        config: TorrentStreamConfig(
          cacheDirectory: cache.path,
          downloadBytesPerSecond: 256 * 1024,
          readAheadBytes: 512 * 1024,
          pieceTimeout: const Duration(seconds: 10),
          pieceCacheBytes: 1024 * 1024,
        ),
      );
      final observations = <TorrentStreamState>[];
      final subscription = session.states.listen(observations.add);
      final client = HttpClient();
      try {
        final files = await session.open(
          TorrentSource.metadata(metadata),
          peers: [peer],
        );
        expect(files.single.length, fixture.length);
        await expectLater(
          session.prepareFile(999),
          throwsA(isA<TorrentStreamException>()),
        );
        final stream = await session.prepareFile(files.single.index);
        expect(stream.uri.host, '127.0.0.1');
        expect(
          await range(client, stream.uri, 131060, 262160),
          fixture.sublist(131060, 262161),
        );
        final responses = await Future.wait([
          range(client, stream.uri, fixture.length - 123, fixture.length - 1),
          range(client, stream.uri, 19, 99),
        ]);
        expect(responses[0], fixture.sublist(fixture.length - 123));
        expect(responses[1], fixture.sublist(19, 100));
        await session.setTransferPaused(true);
        expect(session.state.transferPaused, true);
        await session.setTransferPaused(false);
        seed.pause();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        var completed = false;
        final stalled =
            range(
              client,
              stream.uri,
              3 * 1024 * 1024,
              3 * 1024 * 1024 + 100,
            ).then((bytes) {
              completed = true;
              return bytes;
            });
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        expect(
          completed,
          false,
          reason: 'Uncached data must wait while seed is stopped',
        );
        seed.resume();
        await session.addPeers([peer]);
        expect(
          await stalled.timeout(const Duration(seconds: 30)),
          fixture.sublist(3 * 1024 * 1024, 3 * 1024 * 1024 + 101),
        );
        await session.prepareSeek();
        expect(
          observations.any((s) => s.connectedPeers > 0 && s.connectedSeeds > 0),
          true,
        );
        expect(observations.any((s) => s.downloadBytesPerSecond > 0), true);
        expect(session.state.receivedBytes, greaterThan(0));
        expect(session.state.selectedFile!.index, files.single.index);
        expect(session.state.selectedProgress, greaterThan(0));
        expect(session.state.selectedProgress, lessThan(1));
        expect(session.state.uploadBytesPerSecond, greaterThanOrEqualTo(0));
        expect(
          session.state.knownPeers,
          greaterThanOrEqualTo(session.state.connectedPeers),
        );
        expect(
          session.state.connections,
          greaterThanOrEqualTo(session.state.connectedPeers),
        );
        final received = session.state.receivedBytes;
        final served = session.state.servedBytes;
        expect(session.state.downloadedBytes, lessThan(fixture.length));
        await session.close();
        await session.close();
        expect(session.state.phase, TorrentStreamPhase.closed);
        expect(session.state.receivedBytes, greaterThanOrEqualTo(received));
        expect(session.state.servedBytes, greaterThanOrEqualTo(served));
        expect(session.state.connectedPeers, 0);
        expect(session.state.downloadBytesPerSecond, 0);
        expect(session.state.uploadBytesPerSecond, 0);
        expect(await sentinel.readAsString(), 'preserve');
        expect(
          await cache.list().length,
          1,
          reason: 'Only caller-owned data remains',
        );
        expect(await source.readAsBytes(), fixture);
        await expectLater(
          session.prepareSeek(),
          throwsA(isA<TorrentStreamException>()),
        );
      } finally {
        await subscription.cancel();
        client.close(force: true);
        await session.close();
        native.close();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
  test(
    'close interrupts pending metadata, preserves root, and completes once',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'torrent-stream-cancel-',
      );
      final session = TorrentStreamSession(
        config: TorrentStreamConfig(cacheDirectory: root.path),
      );
      try {
        final opening = session.open(
          TorrentSource.magnet(
            Uri.parse(
              'magnet:?xt=urn:btih:0000000000000000000000000000000000000001',
            ),
          ),
        );
        final cancelled = expectLater(
          opening,
          throwsA(
            isA<TorrentStreamException>().having(
              (e) => e.code,
              'code',
              TorrentStreamErrorCode.cancelled,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final watch = Stopwatch()..start();
        await session.close();
        await cancelled;
        expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
        expect(await root.exists(), true);
        expect(await root.list().length, 0);
      } finally {
        await session.close();
        await root.delete(recursive: true);
      }
    },
  );
}
