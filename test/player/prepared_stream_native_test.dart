import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/prepared_stream.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../packages/torrent_stream/test/engine_support.dart';

void main() {
  test('countdown warms native pieces and transfers its exact HTTP endpoint', () async {
    final root = await Directory.systemTemp.createTemp('sentorr-prefetch-');
    final seedDir = await Directory('${root.path}/seed').create();
    final bytes = Uint8List.fromList(
      List.generate(1024 * 1024 + 9, (i) => (i * 13 + 5) % 251),
    );
    final source = await File('${seedDir.path}/film.mkv').writeAsBytes(bytes);
    final (metadata, peer, closeSeed) = await seedFile(
      source,
      pieceSize: 64 * 1024,
    );
    final torrent = await File('${root.path}/film.torrent')
        .writeAsBytes(metadata);
    final hash = loadTorrentFile(torrent.path).infohashHex;
    final tracker = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    tracker.listen((request) async {
      request.response.add([
        ...ascii.encode('d8:intervali60e5:peers6:'),
        127,
        0,
        0,
        1,
        peer.port >> 8,
        peer.port & 255,
        101,
      ]);
      await request.response.close();
    });
    final release = TorrentRelease(
      source: TorrentSourceId.pirateBay,
      name: 'Film 1080p',
      infoHash: hash,
      magnet: Uri.parse(
        'magnet:?xt=urn:btih:$hash&tr=${Uri.encodeComponent('http://127.0.0.1:${tracker.port}/announce')}',
      ),
      seeders: 1,
      sizeBytes: bytes.length,
      resolution: 1080,
    );
    final candidate = TorrentCandidate(
      release: release,
      score: 1,
      qualityScore: 1,
      availabilityScore: 1,
      sizeScore: 1,
      requiresFileSelection: false,
    );
    final item = PlaybackItem(
      title: ImdbTitle(id: 'tt1', title: 'Film'),
    );
    final engine = loopbackEngine();
    final prepared = PreparedStreams(
      create: (item, candidate) => PendingStream(
        item: item,
        candidate: candidate,
        engine: engine,
        configFor: (_) async =>
            TorrentStreamConfig(cacheDirectory: '${root.path}/cache'),
        fetchMetadata: (_, _) async => metadata,
      ),
    );
    PendingStream? pending;
    final client = HttpClient();
    try {
      prepared.start(item, candidate);
      // Simulate Play after preparation has already started.
      pending = prepared.take(item.id, hash);
      final held = await pending!.ready;
      final warmed = await until(engine, hash, (t) => t.verifiedBytes > 0);
      expect(warmed.owners, hasLength(1));
      final endpoint = held.stream.uri;
      final request = await client.getUrl(endpoint);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-65535');
      final response = await request.close();
      final actual = await response.fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      expect(response.statusCode, HttpStatus.partialContent);
      expect(actual, bytes.sublist(0, 65536));
      expect(held.stream.uri, endpoint);
      expect(engine.torrents, hasLength(1));
      await pending.close();
      expect(engine.torrents, isEmpty);
    } finally {
      client.close(force: true);
      prepared.clear();
      await pending?.close();
      await engine.close();
      closeSeed();
      await tracker.close(force: true);
      await root.delete(recursive: true);
    }
  });
}
