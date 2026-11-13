import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/media/cached_media.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/offline_source.dart';
import 'package:sentorr/player/stream/reusable_torrent.dart';
import 'package:sentorr/player/stream/session_config.dart';
import 'package:sentorr/player/stream/torrent_cache.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/sync/copies.dart';
import 'package:sentorr/sync/peers.dart';
import 'package:sentorr/sync/peer_playback.dart';
import 'package:sentorr/sync/service.dart';
import 'package:sentorr/sync/shared_streams.dart';
import 'package:sentorr/torrents/engine.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../packages/torrent_stream/test/engine_support.dart' as native;
import 'harness.dart';

void main() {
  for (final complete in [false, true]) {
    test(
      'closed cache serves verified bytes with its seed offline (complete=$complete)',
      () async {
        final root = await Directory.systemTemp.createTemp('sentorr-dormant-');
        final bytes = Uint8List.fromList(
          List.generate(2 * 1024 * 1024, (n) => (n * 11) % 251),
        );
        final file = await File('${root.path}/seed/movie.mkv')
            .create(recursive: true);
        await file.writeAsBytes(bytes);
        final (metadata, peer, closeSeed) = await native.seedFile(
          file,
          pieceSize: 64 * 1024,
        );
        final torrentFile = await File('${root.path}/source.torrent')
            .writeAsBytes(metadata);
        final hash = loadTorrentFile(torrentFile.path).infohashHex;
        final item = PlaybackItem(
          title: ImdbTitle(id: 'tt901', title: 'Cached movie'),
        );
        final release = TorrentRelease(
          source: TorrentSourceId.bitsearch,
          name: 'Cached movie 1080p',
          infoHash: hash,
          magnet: Uri.parse('magnet:?xt=urn:btih:$hash'),
          seeders: 1,
          sizeBytes: bytes.length,
        );
        final cache = TorrentCache(
          JsonFileStore(File('${root.path}/index.json')),
        );
        final cacheRoot = '${root.path}/cache';
        await cache.use(cacheRoot, hash, keep: 3);
        final engine = native.loopbackEngine();
        final original = TorrentStreamSession(
          engine: engine,
          config: TorrentStreamConfig(
            cacheDirectory: cacheRoot,
            retainedDirectory: hash,
            readAheadBytes: 1,
            prepareContainer: false,
          ),
        );
        final host = await syncDevice(
          'Host',
          overrides: [
            torrentCacheProvider.overrideWithValue(cache),
            torrentEngineProvider.overrideWithValue(engine),
            cachedStreamLibraryProvider.overrideWithValue((
              list: cache.saved,
              revision: 0,
            )),
            cachedStreamRestoreProvider.overrideWith(
              (ref) =>
                  (id, hash) => openCachedStream(ref, id, hash),
            ),
          ],
        );
        final viewer = await syncDevice(
          'Viewer',
          overrides: [
            downloadsDirectoryProvider.overrideWithValue(
              '${root.path}/downloads',
            ),
          ],
        );
        final http = HttpClient();
        var seedClosed = false;
        Future<List<int>> read(Uri uri, int end) async {
          final request = await http.getUrl(uri);
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-$end');
          final response = await request.close();
          expect(response.statusCode, HttpStatus.partialContent);
          return response.fold<List<int>>(
            [],
            (all, chunk) => all..addAll(chunk),
          );
        }

        try {
          final files = await original.open(
            TorrentSource.metadata(metadata),
            peers: [peer],
          );
          final stream = await original.prepareFile(files.single.index);
          final end = complete ? bytes.length - 1 : 65535;
          expect(await read(stream.uri, end), bytes.sublist(0, end + 1));
          await cache.remember(
            item.id,
            '$cacheRoot/$hash',
            ReusableTorrent.fromFile(release, stream.file, item: item),
            metadata,
          );
          await original.close();
          expect(engine.torrents, isEmpty);
          closeSeed();
          seedClosed = true;
          await pair(host, viewer);
          await viewer.read(peersProvider.notifier).syncWith(idOf(host));
          final offered = viewer
              .read(peersProvider)[idOf(host)]!
              .streams
              .single;
          expect(offered.cached, true);
          expect(offered.version, offered.bufferedVersion);
          final lookup = Provider<Future<PeerFile?>>(
            (ref) => verifiedPeerSource(ref, item, {}),
          );
          final source = (await viewer.read(lookup))!;
          final local = Provider<Future<OfflineSource?>>(
            (ref) => cachedPlaybackFor(ref, item),
          );
          expect(await host.read(local), isA<CachedPlayback>());
          expect(await read(source.url, 65535), bytes.sublist(0, 65536));
          if (complete) {
            final copies = viewer.read(peerCopiesProvider);
            final offer = copies.offer((i) => i.id == item.id);
            expect(offer.isEmpty, false);
            copies.start(offer);
            await until(() => viewer.read(libraryProvider).isNotEmpty);
            final saved = viewer.read(libraryProvider).single;
            expect(await File(saved.path).readAsBytes(), bytes);
          } else {
            // Eviction withdraws the offer while an existing verified-byte lease
            // keeps the folder alive for its current reader.
            await cache.clear([cacheRoot]);
            expect(await cache.find(item.id), isNull);
            expect(Directory('$cacheRoot/$hash').existsSync(), true);
            expect(await read(source.url, 65535), bytes.sublist(0, 65536));
          }
          await host.read(syncServiceProvider).close();
          if (!complete) {
            await until(() => !Directory('$cacheRoot/$hash').existsSync());
          }
        } finally {
          http.close(force: true);
          await host.read(syncServiceProvider).close();
          await viewer.read(syncServiceProvider).close();
          await original.close();
          await engine.close();
          if (!seedClosed) closeSeed();
          await cache.close();
          await root.delete(recursive: true);
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }
}
