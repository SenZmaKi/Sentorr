import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/shared/net/net.dart';
import 'package:sentorr/sync/copies.dart';
import 'package:sentorr/sync/peers.dart';
import 'package:sentorr/torrents/models.dart';

import '../sync/harness.dart';

void main() {
  for (final online in [true, false]) {
    for (final damaged in [false, true]) {
      test('paired HTTPS copy: online=$online, damaged=$damaged', () async {
        final root = await Directory.systemTemp.createTemp(
          'sentorr-peer-validation-',
        );
        addTearDown(() => root.delete(recursive: true));
        final file = File('${root.path}/source/movie.mp4');
        await file.parent.create(recursive: true);
        final bytes = Uint8List.fromList(
          List.generate(256 * 1024, (i) => i % 251),
        );
        await file.writeAsBytes(bytes);
        final metadata = createTorrentData(
          sourcePath: file.path,
          pieceSize: 65536,
        );
        final torrent = await File('${root.path}/source.torrent')
            .writeAsBytes(metadata);
        final hash = loadTorrentFile(torrent.path).infohashHex;
        var requests = 0;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((r) async {
          requests++;
          r.response.add(metadata);
          await r.response.close();
        });
        if (damaged) {
          final corrupt = Uint8List.fromList(bytes);
          corrupt.fillRange(65536, 131072, 0);
          await file.writeAsBytes(corrupt);
        }
        final release = TorrentRelease(
          source: TorrentSourceId.bitsearch,
          name: 'Fixture',
          infoHash: hash,
          magnet: Uri.parse('magnet:?xt=urn:btih:$hash'),
          torrentUrls: [Uri.parse('http://127.0.0.1:${server.port}/metadata')],
          seeders: 1,
          sizeBytes: bytes.length,
        );
        final item = PlaybackItem(
          title: ImdbTitle(id: 'tt901', title: 'Peer validation'),
        );
        final source = await syncDevice(
          'Source',
          library: [
            LibraryEntry(
              item: item,
              downloadId: 'source',
              release: release,
              fileIndex: 0,
              path: file.path,
              addedAt: DateTime.now(),
            ),
          ],
        );
        final network = NetworkClient(http2: false, logging: false);
        addTearDown(() => network.dio.close(force: true));
        final receiver = await syncDevice(
          'Receiver',
          internetProbe: () async => online,
          overrides: [
            downloadsDirectoryProvider.overrideWithValue(
              '${root.path}/receive',
            ),
            networkClientProvider.overrideWithValue(network),
          ],
        );
        await pair(source, receiver);
        await receiver.read(peersProvider.notifier).syncWith(idOf(source));
        final copies = receiver.read(peerCopiesProvider);
        final offer = copies.offer((i) => i.id == item.id);
        expect(offer.isEmpty, isFalse);
        copies.start(offer);
        final timer = Stopwatch()..start();
        while (receiver.read(copyingProvider).isNotEmpty) {
          if (timer.elapsed > const Duration(seconds: 30)) {
            fail('copy validation stalled');
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        final entries = receiver.read(libraryProvider);
        if (online && damaged) {
          expect(
            entries,
            isEmpty,
            reason: 'damaged transfer must not enter the library',
          );
        } else {
          expect(entries, hasLength(1));
          expect(
            await File(entries.single.path).readAsBytes(),
            await file.readAsBytes(),
          );
        }
        expect(
          requests,
          online ? 1 : 0,
          reason: 'offline trust must not request internet metadata',
        );
      }, timeout: const Timeout(Duration(seconds: 45)));
    }
  }
}
