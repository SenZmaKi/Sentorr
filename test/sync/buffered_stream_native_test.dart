import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/offline_source.dart';
import 'package:sentorr/sync/peers.dart';
import 'package:sentorr/sync/service.dart';
import 'package:sentorr/sync/shared_streams.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../packages/torrent_stream/test/engine_support.dart' as native;
import 'harness.dart';

void main() {
  for (final paused in [false, true]) {
    test(
      'paired device retains verified partial bytes after local close (paused=$paused)',
      () async {
        final root = await Directory.systemTemp.createTemp('peer-buffered-');
        final bytes = Uint8List.fromList(
          List.generate(4 * 1024 * 1024, (n) => (n * 7) % 251),
        );
        final file = await File('${root.path}/seed/movie.mkv')
            .create(recursive: true);
        await file.writeAsBytes(bytes);
        final (metadata, peer, closeSeed) = await native.seedFile(
          file,
          pieceSize: 64 * 1024,
        );
        final torrent = await File('${root.path}/movie.torrent')
            .writeAsBytes(metadata);
        final hash = loadTorrentFile(torrent.path).infohashHex;
        final engine = native.loopbackEngine();
        final session = TorrentStreamSession(
          engine: engine,
          config: TorrentStreamConfig(
            cacheDirectory: '${root.path}/cache',
            readAheadBytes: 1,
            prepareContainer: false,
          ),
        );
        final http = HttpClient();
        final host = await syncDevice('Host');
        final viewer = await syncDevice('Viewer');
        Future<List<int>> read(Uri uri, String range) async {
          final request = await http.getUrl(uri);
          request.headers.set(HttpHeaders.rangeHeader, range);
          final response = await request.close();
          expect(response.statusCode, HttpStatus.partialContent);
          return response.fold<List<int>>([], (all, data) => all..addAll(data));
        }

        try {
          final files = await session.open(
            TorrentSource.metadata(metadata),
            peers: [peer],
          );
          final stream = await session.prepareFile(files.single.index);
          await read(stream.uri, 'bytes=0-65535');
          await until(() => session.state.selectedBytes > 0);
          expect(session.state.selectedBytes, lessThan(bytes.length));
          final item = PlaybackItem(
            title: ImdbTitle(id: 'tt1', title: 'Movie'),
          );
          final release = TorrentRelease(
            source: TorrentSourceId.pirateBay,
            name: 'Movie',
            infoHash: hash,
            magnet: Uri.parse('magnet:?xt=urn:btih:$hash'),
            seeders: 1,
            sizeBytes: bytes.length,
          );
          final candidate = TorrentCandidate(
            release: release,
            score: 1,
            qualityScore: 1,
            availabilityScore: 1,
            sizeScore: 1,
            requiresFileSelection: false,
          );
          if (paused) await session.setTransferPaused(true);
          host
              .read(sharedStreamsProvider.notifier)
              .register(SharedStream(item, candidate, session, stream));
          await pair(host, viewer);
          await until(
            () =>
                viewer.read(peersProvider)[idOf(host)]?.streams.isNotEmpty ==
                true,
          );
          final peerSource =
              viewer.read(peersProvider.notifier).sourceFor(item) as PeerFile;
          expect(peerSource.buffered, isTrue);
          expect(viewer.read(peersProvider)[idOf(host)]!.media, isEmpty);
          expect(
            await read(peerSource.url, 'bytes=0-65535'),
            bytes.sublist(0, 65536),
          );
          expect(engine.torrents.single.owners.length, 2);
          final wrong = peerSource.url.replace(
            queryParameters: {'buffered': '1', 'hash': '0' * 40},
          );
          final refused = await (await http.getUrl(wrong)).close();
          expect(refused.statusCode, HttpStatus.notFound);
          await refused.drain<void>();
          await session.close();
          expect(engine.torrents.single.owners.length, 1);
          if (paused) {
            // Explicit test peers have no tracker to rediscover a disconnected
            // seed immediately. Verify cached delivery independently of reconnect.
            expect(
              await read(peerSource.url, 'bytes=0-65535'),
              bytes.sublist(0, 65536),
            );
          } else {
            expect(
              await read(peerSource.url, 'bytes=2097152-2162687'),
              bytes.sublist(2097152, 2162688),
            );
          }
          await host.read(syncServiceProvider).close();
          expect(engine.torrents, isEmpty);
        } finally {
          http.close(force: true);
          await host.read(syncServiceProvider).close();
          await viewer.read(syncServiceProvider).close();
          await session.close();
          await engine.close();
          closeSeed();
          await root.delete(recursive: true);
        }
      },
    );
  }
}
