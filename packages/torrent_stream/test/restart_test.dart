import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:torrent_stream/torrent_stream.dart';

import 'engine_support.dart';

void main() {
  for (final (legacy, corrupt) in [
    (false, false),
    (true, false),
    (true, true),
  ]) {
    test(
      'retained pieces survive restart without seed (legacy: $legacy, corrupt: $corrupt)',
      () async {
        final root = await Directory.systemTemp.createTemp('stream-restart-');
        final source = File('${root.path}/seed/video.bin');
        await source.create(recursive: true);
        final bytes = Uint8List.fromList(
          List.generate(4 * 1024 * 1024, (i) => (i * 17 + 3) % 251),
        );
        await source.writeAsBytes(bytes);
        final (metadata, peer, stopSeed) = await seedFile(source);
        var engine = loopbackEngine();
        final config = TorrentStreamConfig(
          cacheDirectory: '${root.path}/cache',
          retainedDirectory: 'retained',
          readAheadBytes: 128 * 1024,
          pieceCacheBytes: 0,
          pieceTimeout: const Duration(seconds: 3),
        );
        var session = TorrentStreamSession(engine: engine, config: config);
        final client = HttpClient();
        Future<List<int>> read(Uri uri) async {
          final request = await client.getUrl(uri);
          request.headers.set('Range', 'bytes=0-65535');
          final response = await request.close();
          expect(response.statusCode, 206);
          return response.fold<List<int>>(
            [],
            (all, chunk) => all..addAll(chunk),
          );
        }

        var seedStopped = false;
        try {
          final files = await session.open(
            TorrentSource.metadata(metadata),
            peers: [peer],
          );
          final stream = await session.prepareFile(files.single.index);
          expect(await read(stream.uri), bytes.sublist(0, 65536));
          await session.close();
          await engine.close();
          if (legacy) {
            // Produce a genuine old-style cache: priority-zero file bytes live
            // in libtorrent's partfile, with no normal media file or resume.
            final retained = Directory('${root.path}/cache/retained');
            await retained.delete(recursive: true);
            await retained.create();
            final old = createSessionFromTags([
              LibtorrentTagItem.settingsBool(
                LibtorrentSettingsTag.enableDht,
                false,
              ),
              LibtorrentTagItem.settingsBool(
                LibtorrentSettingsTag.enableLsd,
                false,
              ),
              LibtorrentTagItem.settingsBool(
                LibtorrentSettingsTag.enableUpnp,
                false,
              ),
              LibtorrentTagItem.settingsBool(
                LibtorrentSettingsTag.enableNatpmp,
                false,
              ),
            ]);
            try {
              final handle = old.addTorrentData(
                torrentData: metadata,
                savePath: retained.path,
              );
              handle.unsetFlags(
                LibtorrentTorrentFlags.autoManaged |
                    LibtorrentTorrentFlags.paused,
              );
              handle.prioritizeFiles([0]);
              final clock = Stopwatch()..start();
              while (handle.getFilePriorities().single != 0) {
                if (clock.elapsed > const Duration(seconds: 10)) {
                  throw StateError('Legacy priorities');
                }
                await Future<void>.delayed(const Duration(milliseconds: 20));
              }
              handle.setPiecePriority(0, 7);
              handle.setPiecePriority(1, 7);
              handle.connectPeer(address: peer.address, port: peer.port);
              while (!handle.havePiece(0) ||
                  !handle.havePiece(1) ||
                  handle.getDownloadQueue().any((q) => q.writing > 0)) {
                if (clock.elapsed > const Duration(seconds: 15)) {
                  throw StateError('Legacy piece');
                }
                await Future<void>.delayed(const Duration(milliseconds: 20));
              }
            } finally {
              old.close();
            }
          }
          if (corrupt) {
            final part = Directory('${root.path}/cache/retained')
                .listSync()
                .whereType<File>()
                .singleWhere((file) => file.path.endsWith('.parts'));
            final input = await part.open(mode: FileMode.append);
            try {
              await input.setPosition(0);
              final header = ByteData.sublistView(await input.read(12));
              final count = header.getUint32(0), size = header.getUint32(4);
              final slot = header.getUint32(8);
              final start =
                  ((8 + count * 4 + 1023) ~/ 1024) * 1024 + slot * size;
              await input.setPosition(start);
              final byte = (await input.read(1)).single;
              await input.setPosition(start);
              await input.writeByte(byte ^ 255);
            } finally {
              await input.close();
            }
          }
          stopSeed();
          seedStopped = true;
          engine = loopbackEngine();
          session = TorrentStreamSession(engine: engine, config: config);
          final restored = await session.open(TorrentSource.metadata(metadata));
          final replay = await session.prepareFile(restored.single.index);
          final snapshot = await until(
            engine,
            engine.torrents.single.infoHash,
            (t) => t.fileBytes.single > 0,
          );
          expect(snapshot.fileBytes.single, lessThan(bytes.length));
          expect(snapshot.fileBytes.single, greaterThan(0));
          expect(snapshot.streams.single.downloadedRanges, isNotEmpty);
          if (corrupt) {
            await expectLater(read(replay.uri), throwsA(isA<HttpException>()));
          } else {
            expect(await read(replay.uri), bytes.sublist(0, 65536));
          }
          expect(session.state.receivedBytes, 0);
        } finally {
          client.close(force: true);
          await session.close();
          await engine.close();
          if (!seedStopped) stopSeed();
          await root.delete(recursive: true);
        }
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );
  }
}
