import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/backup/backup_bundle.dart';
import 'package:sentorr/backup/drive/drive_auth.dart';
import 'package:sentorr/backup/drive/drive_client.dart';
import 'package:sentorr/backup/remote.dart';
import 'package:sentorr/backup/watch_backup.dart';
import 'package:sentorr/following/snapshot.dart';
import 'package:sentorr/watching/models.dart';

import '../support/fake_imdb.dart';

class _SignedIn extends DriveAuth {
  _SignedIn() : super(dio: Dio(), openBrowser: (_) async => true);
  @override
  Future<String> accessToken() async => 'token';
}

class _Store implements HttpClientAdapter {
  final files = <String, ({String name, String source})>{};
  final requests = <RequestOptions>[];
  int sequence = 0;
  DriveBackupClient client() => DriveBackupClient(
    dio: Dio()..httpClientAdapter = this,
    auth: _SignedIn(),
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    Object body = {};
    if (options.path.endsWith('/drive/v3/files') && options.method == 'GET') {
      body = {
        'files': [
          for (final entry in files.entries)
            {'id': entry.key, 'name': entry.value.name},
        ],
      };
    } else if (options.path.contains('/upload/') && options.method == 'POST') {
      final parts = (options.data as String).split('\r\n\r\n');
      final metadata = jsonDecode(parts[1].split('\r\n--')[0]) as Map;
      files['new${++sequence}'] = (
        name: metadata['name'] as String,
        source: parts[2].split('\r\n--')[0],
      );
    } else if (options.method == 'DELETE') {
      files.remove(options.path.split('/').last);
    } else if (options.method == 'GET') {
      body = files[options.path.split('/').last]!.source;
    }
    return ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [
          body is String ? 'text/plain' : 'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

BackupBundle _bundle(int id) => BackupBundle(
  watch: WatchSnapshot([
    WatchEntry(
      title: fakeTitle(id),
      position: const Duration(minutes: 18),
      duration: const Duration(minutes: 45),
      updatedAt: DateTime.now(),
    ),
  ], {}),
  following: const FollowedSnapshot([], {}),
);

void main() {
  test('both channels share the canonical snapshot name and migrate nightly snapshots', () async {
    final store = _Store();
    store.files['stable'] = (
      name: 'sentorr-backup.json',
      source: _bundle(1).encode(),
    );
    store.files['nightly'] = (
      name: 'sentorr-nightly-backup.json',
      source: _bundle(2).encode(),
    );
    final client = store.client();
    final held = (await client.download())!;
    expect(held.bundle.watch.entries.map((e) => e.id).toSet(), {'tt1', 'tt2'});
    expect(held.needsPublication, isTrue);
    final query = store.requests.first.queryParameters['q'] as String;
    expect(query, contains("name = 'sentorr-backup.json'"));
    expect(query, contains("name = 'sentorr-nightly-backup.json'"));
    await client.upload(held.bundle, basedOn: held.revision);
    expect(store.files.values.single.name, 'sentorr-backup.json');
    expect(
      (await store.client().download())!.bundle.watch.entries,
      hasLength(2),
    );
    expect(DriveBackupClient.fileName, 'sentorr-backup.json');
  });

  test(
    'an unsupported snapshot blocks the whole exchange and all writes',
    () async {
      final store = _Store();
      store.files['good'] = (
        name: 'sentorr-backup.json',
        source: _bundle(1).encode(),
      );
      final bad = jsonDecode(_bundle(2).encode()) as Map<String, dynamic>;
      bad['formats'] = {'watch': 99, 'following': 1, 'lists': 1};
      store.files['bad'] = (
        name: 'sentorr-backup.json',
        source: jsonEncode(bad),
      );
      final client = store.client();
      await expectLater(client.download(), throwsA(isA<BackupException>()));
      await expectLater(
        client.upload(_bundle(3), basedOn: null),
        throwsA(isA<BackupConflict>()),
      );
      expect(store.files.keys, containsAll(['good', 'bad']));
      expect(store.requests.every((r) => r.method == 'GET'), isTrue);
    },
  );

  test('a failed reread cannot reuse prior permission to upload', () async {
    final store = _Store();
    store.files['good'] = (
      name: 'sentorr-backup.json',
      source: _bundle(1).encode(),
    );
    final client = store.client();
    final held = (await client.download())!;
    store.files['newer'] = (
      name: 'sentorr-backup.json',
      source: '{"format":"sentorr-backup","version":99}',
    );
    await expectLater(client.download(), throwsA(isA<BackupException>()));
    await expectLater(
      client.upload(held.bundle, basedOn: held.revision),
      throwsA(isA<BackupConflict>()),
    );
    expect(store.requests.every((r) => r.method == 'GET'), isTrue);
  });

  test('malformed records are not silently compacted away', () async {
    final store = _Store();
    final bad = jsonDecode(_bundle(1).encode()) as Map<String, dynamic>;
    (bad['watch'] as Map)['entries'] = [{}];
    store.files['bad'] = (name: 'sentorr-backup.json', source: jsonEncode(bad));
    final client = store.client();
    await expectLater(client.download(), throwsA(isA<BackupException>()));
    await expectLater(
      client.upload(_bundle(2), basedOn: null),
      throwsA(isA<BackupConflict>()),
    );
    expect(store.files, hasLength(1));
  });
}
