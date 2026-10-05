import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/torrents/sources/nyaa.dart';
import 'package:test/test.dart';

const hash = '0123456789abcdef0123456789abcdef01234567';
String row({
  String name = '[Group] Big Buck Bunny (2008) [1080p]',
  String seeds = '9',
  String category = 'Anime - English-translated',
}) =>
    '''
<tr><td><a title="$category"></a></td>
<td><a href="/view/123">$name</a><a href="/view/123#comments">2</a></td>
<td><a href="/download/123.torrent"></a><a href="magnet:?xt=urn:btih:$hash&amp;dn=Example"></a></td>
<td>1.5 GiB</td><td data-timestamp="1234567890"></td>
<td>$seeds</td><td>1</td><td>50</td></tr>''';
String page(String rows) =>
    '<table class="torrent-list"><tbody>$rows</tbody></table>';

void main() {
  late Dio dio;
  late String body;
  late List<RequestOptions> requests;
  final animation = TorrentQuery(
    title: 'Big Buck Bunny',
    year: 2008,
    genres: {'Animation'},
  );
  setUp(() {
    body = page(row());
    requests = [];
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            requests.add(o);
            h.resolve(Response(requestOptions: o, statusCode: 200, data: body));
          },
        ),
      );
  });
  tearDown(() => dio.close(force: true));

  test(
    'conditional source skips ordinary media and preserves genre variants',
    () async {
      final result = await TorrentRepository([NyaaSource(dio)])
          .search(TorrentQuery(title: 'Big Buck Bunny'));
      expect(requests, isEmpty);
      expect(result.diagnostics.single.status, SourceSearchStatus.unsupported);
      expect(
        NyaaSource(dio)
            .supports(animation.withSearchStyle(TorrentSearchStyle.longForm)),
        isTrue,
      );
      expect(
        NyaaSource(dio)
            .supports(TorrentQuery(title: 'Film', genres: {' animation '})),
        isTrue,
      );
    },
  );

  test(
    'parses magnet, title excluding comments, binary size, UTC date and seeds',
    () async {
      final releases = await NyaaSource(dio).search(animation);
      expect(releases, hasLength(1));
      final release = releases.single;
      expect(release.name, '[Group] Big Buck Bunny (2008) [1080p]');
      expect(release.infoHash, hash);
      expect(release.seeders, 9);
      expect(release.sizeBytes, 1610612736);
      expect(release.uploadedAt!.isUtc, isTrue);
      expect(release.resolution, 1080);
      expect(
        release.torrentUrls.single,
        Uri.parse('https://nyaa.si/download/123.torrent'),
      );
      expect(requests.single.uri.queryParameters, {
        'q': 'Big Buck Bunny 2008',
        'c': '1_2',
        's': 'seeders',
        'o': 'desc',
        'p': '1',
      });
    },
  );

  test(
    'malformed rows, wrong category, wrong title and dead swarms are rejected',
    () async {
      body = page(
        '${row()}<tr><td>broken</td></tr>${row(seeds: "0")}'
        '${row(category: "Literature")}${row(name: "Different Film 2008")}'
        '${row(seeds: "NaN")}',
      );
      expect(await NyaaSource(dio).search(animation), hasLength(1));
      body = page('');
      expect(await NyaaSource(dio).search(animation), isEmpty);
      body = '<html>Just a moment</html>';
      final result = await TorrentRepository([NyaaSource(dio)])
          .search(animation);
      expect(result.failures.single.message, 'Unrecognized Nyaa search page');
    },
  );

  test(
    'explicit scene episodes match; ambiguous absolute numbering fails closed',
    () async {
      final query = TorrentQuery(
        title: 'Example Show',
        genres: {'Animation'},
        season: 2,
        episode: 3,
      );
      body = page(
        '${row(name: "[Group] Example Show S02E03 [1080p]")}'
        '${row(name: "[Group] Example Show - 03 [1080p]")}'
        '${row(name: "[Group] Example Show S01E03 [1080p]")}',
      );
      expect(await NyaaSource(dio).search(query), hasLength(1));
    },
  );

  test('five concurrent requests across instances; queued cancellation frees capacity', () async {
    dio.interceptors.clear();
    final enteredFive = Completer<void>();
    final release = Completer<void>();
    var active = 0, peak = 0, entered = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) async {
          entered++;
          active++;
          if (active > peak) peak = active;
          if (entered == 5) enteredFive.complete();
          await release.future;
          active--;
          h.resolve(
            Response(requestOptions: o, statusCode: 200, data: page('')),
          );
        },
      ),
    );
    final searches = List.generate(5, (_) => NyaaSource(dio).search(animation));
    await enteredFive.future;
    final token = CancelToken();
    final cancelled = NyaaSource(dio).search(animation, cancelToken: token);
    final assertion = expectLater(cancelled, throwsA(isA<DioException>()));
    searches.add(NyaaSource(dio).search(animation));
    await Future<void>.delayed(Duration.zero);
    expect(entered, 5);
    token.cancel();
    await assertion;
    release.complete();
    await Future.wait(searches);
    expect(peak, 5);
    expect(entered, 6);
    await NyaaSource(dio).search(animation);
    expect(entered, 7);
  });
}
