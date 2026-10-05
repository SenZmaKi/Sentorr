import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sentorr/shared/source_directory/models.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/torrents/sources/pirate_bay.dart';
import 'package:test/test.dart';

Map<String, dynamic> directory({
  String endpoint = 'https://new.example/q.php',
  DateTime? expiry,
}) => {
  'version': 1,
  'expiresAt': (expiry ?? DateTime.now().toUtc().add(const Duration(days: 1)))
      .toIso8601String(),
  'sources': {
    for (final id in TorrentSourceId.values)
      id.name: {
        'apiEntryPoint': endpoint,
        'allowedHosts': ['new.example'],
      },
  },
};
void main() {
  test(
    'all adapters have entries and only HTTPS allowlisted hosts are accepted',
    () {
      expect(
        SourceDirectory.fromJson(directory()).endpoints.length,
        TorrentSourceId.values.length,
      );
      for (final endpoint in [
        'http://new.example/q',
        'https://user@new.example/q',
        'https://new.example:8443/q',
        'https://other.example/q',
      ]) {
        expect(
          () => SourceDirectory.fromJson(directory(endpoint: endpoint)),
          throwsFormatException,
        );
      }
      expect(
        () => SourceDirectory.fromJson(directory(expiry: DateTime.utc(2000))),
        throwsFormatException,
      );
      final missing = directory();
      (missing['sources'] as Map).remove('yts');
      expect(() => SourceDirectory.fromJson(missing), throwsFormatException);
    },
  );
  test('older directories retain the built-in Nyaa endpoint', () {
    final old = directory();
    (old['sources'] as Map).remove('nyaa');
    expect(
      SourceDirectory.fromJson(old).endpoints[TorrentSourceId.nyaa],
      'https://nyaa.si/',
    );
  });
  test(
    'first search waits for refresh and uses endpoint changed during that wait',
    () async {
      final dio = Dio();
      final requests = <Uri>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            requests.add(o.uri);
            h.resolve(Response(requestOptions: o, statusCode: 200, data: []));
          },
        ),
      );
      var endpoint = 'https://old.example/q';
      final refresh = Completer<void>();
      final repo = TorrentRepository([
        PirateBaySource(dio, endpointResolver: () => endpoint),
      ], beforeSearch: () => refresh.future);
      final search = repo.search(TorrentQuery(title: 'Example'));
      await Future<void>.delayed(Duration.zero);
      expect(requests, isEmpty);
      endpoint = 'https://new.example/q';
      refresh.complete();
      await search;
      expect(requests.single.host, 'new.example');
      dio.close();
    },
  );
}
