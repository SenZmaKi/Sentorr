import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/torrents/metadata_fetcher.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/parsing.dart';

import '../support/fake_torrents.dart';

void main() {
  late Dio dio;
  late TorrentMetadataFetcher fetcher;
  final original = fakeRelease(1);
  final release = TorrentRelease(
    source: original.source,
    name: original.name,
    infoHash: original.infoHash,
    magnet: original.magnet,
    torrentUrls: [Uri.parse('https://provider.test/movie.torrent')],
    seeders: 1,
    sizeBytes: 100,
  );
  final requested = <Uri>[];
  late ResponseBody Function(RequestOptions) response;
  setUp(() {
    requested.clear();
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            requested.add(o.uri);
            h.resolve(
              Response(requestOptions: o, statusCode: 200, data: response(o)),
            );
          },
        ),
      );
    fetcher = TorrentMetadataFetcher(dio);
  });
  tearDown(() => dio.close(force: true));

  test(
    'downloads provider bytes without fetching unchosen torrents or magnets',
    () async {
      response = (_) => ResponseBody.fromString('d4:infodee', 200);
      expect(
        await fetcher.fetch(release, CancelToken()),
        'd4:infodee'.codeUnits,
      );
      expect(requested, release.torrentUrls);
    },
  );

  test(
    'stronger cache-only result retains provider URL and tracker hints',
    () async {
      final provider = TorrentRelease(
        source: release.source,
        name: release.name,
        infoHash: release.infoHash,
        magnet: release.magnet.replace(
          queryParameters: {
            ...release.magnet.queryParameters,
            'tr': 'https://tracker.test/announce',
          },
        ),
        torrentUrls: release.torrentUrls,
        seeders: 1,
        sizeBytes: 100,
      );
      final cache = TorrentRelease(
        source: TorrentSourceId.pirateBay,
        name: 'Stronger',
        infoHash: release.infoHash,
        magnet: release.magnet,
        torrentUrls: [torrentCacheUrl(release.infoHash)],
        seeders: 100,
        sizeBytes: 100,
      );
      final merged = provider.merge(cache);
      expect(merged.seeders, 100);
      expect(merged.trackers, [Uri.parse('https://tracker.test/announce')]);
      response = (_) => ResponseBody.fromString('d4:infodee', 200);
      await fetcher.fetch(merged, CancelToken());
      expect(requested, release.torrentUrls);
    },
  );

  test('HTML challenge falls back to HTTP cache, never a magnet', () async {
    response = (o) => ResponseBody.fromString(
      o.uri.host == 'provider.test' ? '<html>Challenge</html>' : 'd4:infodee',
      200,
    );
    await fetcher.fetch(release, CancelToken());
    expect(requested.map((u) => u.host), ['provider.test', 'itorrents.org']);
    expect(
      requested.last.path,
      '/torrent/${release.infoHash.toUpperCase()}.torrent',
    );
  });

  test('limits streamed bytes without relying on Content-Length', () async {
    response = (_) => ResponseBody(
      Stream.value(Uint8List(TorrentMetadataFetcher.maxBytes + 1)..[0] = 100),
      200,
    );
    await expectLater(
      fetcher.fetch(release, CancelToken()),
      throwsA(isA<SourceException>()),
    );
    expect(requested, hasLength(2));
  });

  test('cancellation aborts the body and skips cache fallback', () async {
    final stream = StreamController<Uint8List>();
    response = (_) => ResponseBody(stream.stream, 200);
    final cancel = CancelToken();
    final pending = fetcher.fetch(release, cancel);
    final rejected = expectLater(pending, throwsA(isA<DioException>()));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    cancel.cancel('superseded');
    await rejected.timeout(const Duration(seconds: 2));
    expect(requested, hasLength(1));
    await stream.close();
  });
}
