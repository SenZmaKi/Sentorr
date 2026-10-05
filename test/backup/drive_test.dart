import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

typedef _Reply = (int, Object?);

/// Answers requests from [handler] and records them.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final FutureOr<_Reply> Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = await handler(options);
    return ResponseBody.fromString(
      body is String ? body : jsonEncode(body ?? {}),
      status,
      headers: {
        Headers.contentTypeHeader: [
          body is String ? 'text/plain' : Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Adapter adapter) => Dio()..httpClientAdapter = adapter;

final _snapshot = WatchSnapshot([
  WatchEntry(
    title: fakeTitle(1),
    position: const Duration(minutes: 3),
    duration: const Duration(minutes: 90),
    updatedAt: DateTime.now(),
  ),
], {});

final _bundle = BackupBundle(
  watch: _snapshot,
  following: const FollowedSnapshot([], {}),
);

DriveAuth _auth(Dio dio, {Future<bool> Function(Uri)? open}) => DriveAuth(
  dio: dio,
  openBrowser: open ?? (_) async => true,
  clientId: 'id',
  clientSecret: 'secret',
  signInTimeout: const Duration(seconds: 5),
);

/// Signs in through the real loopback redirect, answering Google's side.
Future<DriveAuth> _connected(_Adapter adapter) async {
  final dio = _dio(adapter);
  final auth = _auth(
    dio,
    open: (url) async {
      final redirect = Uri.parse(url.queryParameters['redirect_uri']!).replace(
        queryParameters: {'code': 'abc', 'state': url.queryParameters['state']},
      );
      final client = HttpClient();
      unawaited(
        client
            .getUrl(redirect)
            .then((r) => r.close())
            .then((_) => client.close()),
      );
      return true;
    },
  );
  await auth.connect();
  return auth;
}

_Reply _tokens(RequestOptions o) =>
    (200, {'access_token': 'access', 'expires_in': 3600, 'refresh_token': 'r'});

void main() {
  group('DriveAuth', () {
    test('trades the redirected code for tokens, with PKCE', () async {
      final adapter = _Adapter(_tokens);
      final auth = await _connected(adapter);
      expect(auth.connected, isTrue);
      expect(await auth.accessToken(), 'access');
      final form = adapter.requests.single.data as Map;
      expect(form['code'], 'abc');
      expect(form['code_verifier'], isNotEmpty);
      expect(form['grant_type'], 'authorization_code');
      expect(form['client_secret'], 'secret');
    });

    test('opens Google with the read-only app folder scope', () async {
      Uri? opened;
      final auth = _auth(
        _dio(_Adapter(_tokens)),
        open: (url) async {
          opened = url;
          return false;
        },
      );
      await expectLater(auth.connect(), throwsA(isA<BackupException>()));
      expect(opened!.queryParameters['scope'], endsWith('drive.appdata'));
      expect(opened!.queryParameters['code_challenge_method'], 'S256');
    });

    test('signs out when Google refuses the saved sign-in', () async {
      var refusing = false;
      final adapter = _Adapter(
        (o) => refusing ? (400, {'error': 'invalid_grant'}) : _tokens(o),
      );
      final auth = await _connected(adapter);
      refusing = true;
      await expectLater(auth.refresh(), throwsA(isA<BackupException>()));
      expect(auth.connected, isFalse);
    });
  });

  group('DriveBackupClient', () {
    test('creates the file when none exists', () async {
      final adapter = _Adapter(
        (o) => o.path.contains('/drive/v3/files')
            ? (200, {'files': []})
            : _tokens(o),
      );
      final auth = await _connected(adapter);
      final client = DriveBackupClient(dio: _dio(adapter), auth: auth);
      expect(await client.download(), isNull);
      await client.upload(_bundle, basedOn: null);
      final upload = adapter.requests.last;
      expect(upload.method, 'POST');
      expect(upload.queryParameters['uploadType'], 'multipart');
      expect(upload.data as String, contains('"parents":["appDataFolder"]'));
      expect(upload.headers['Authorization'], 'Bearer access');
    });

    _Reply existing(RequestOptions o) {
      if (o.path.endsWith('/drive/v3/files')) {
        return (
          200,
          {
            'files': [
              {'id': 'f1', 'md5Checksum': 'm1'},
            ],
          },
        );
      }
      if (o.path.endsWith('/files/f1') && o.method == 'GET') {
        return (200, _bundle.encode());
      }
      if (o.method == 'PATCH') return (200, {});
      return _tokens(o);
    }

    test(
      'unchanged checksums reuse snapshots and changed checksums refetch',
      () async {
        var checksum = 'm1';
        final adapter = _Adapter((o) {
          if (o.path.endsWith('/drive/v3/files')) {
            return (
              200,
              {
                'files': [
                  {'id': 'f1', 'md5Checksum': checksum},
                ],
              },
            );
          }
          return existing(o);
        });
        final auth = await _connected(adapter);
        final client = DriveBackupClient(dio: _dio(adapter), auth: auth);
        await client.download();
        await client.download();
        expect(
          adapter.requests.where((o) => o.path.endsWith('/files/f1')),
          hasLength(1),
        );
        checksum = 'm2';
        await client.download();
        expect(
          adapter.requests.where((o) => o.path.endsWith('/files/f1')),
          hasLength(2),
        );
      },
    );

    test('snapshot requests are bounded and overlap', () async {
      var active = 0, peak = 0;
      final gate = Completer<void>();
      final started = Completer<void>();
      final adapter = _Adapter((o) async {
        if (o.path.endsWith('/drive/v3/files')) {
          return (
            200,
            {
              'files': [
                for (var i = 0; i < 9; i++) {'id': 'f$i'},
              ],
            },
          );
        }
        if (o.path.contains('/drive/v3/files/')) {
          active++;
          if (active > peak) peak = active;
          if (active == 4 && !started.isCompleted) started.complete();
          await gate.future;
          active--;
          return (200, _bundle.encode());
        }
        return _tokens(o);
      });
      final auth = await _connected(adapter);
      final client = DriveBackupClient(dio: _dio(adapter), auth: auth);
      final download = client.download();
      await started.future.timeout(const Duration(seconds: 5));
      expect(peak, 4);
      gate.complete();
      expect(await download, isNotNull);
      expect(active, 0);
      expect(peak, 4);
    });

    test('publishes before compacting the existing file', () async {
      final adapter = _Adapter(existing);
      final auth = await _connected(adapter);
      final client = DriveBackupClient(dio: _dio(adapter), auth: auth);
      final held = (await client.download())!;
      expect(held.bundle.watch.entries.single.id, 'tt1');
      expect(held.revision, 'f1');
      await client.upload(_bundle, basedOn: held.revision);
      expect(adapter.requests.last.method, 'DELETE');
      final publish = adapter.requests.indexWhere(
        (r) => r.method == 'POST' && r.path.contains('/upload/'),
      );
      final cleanup = adapter.requests.indexWhere((r) => r.method == 'DELETE');
      expect(publish, greaterThan(0));
      expect(cleanup, greaterThan(publish));
    });

    test('concurrent publishers retain both states and compact only observed files', () async {
      var sequence = 0;
      final files = <String, String>{'f0': _bundle.encode()};
      final adapter = _Adapter((o) {
        if (o.path.endsWith('/drive/v3/files') && o.method == 'GET') {
          return (
            200,
            {
              'files': [
                for (final id in files.keys) {'id': id},
              ],
            },
          );
        }
        if (o.path.contains('/upload/') && o.method == 'POST') {
          final source = (o.data as String)
              .split('\r\n\r\n')[2]
              .split('\r\n--')[0];
          files['f${++sequence}'] = source;
          return (200, {});
        }
        final id = o.path.split('/').last;
        if (o.method == 'GET' && files.containsKey(id)) return (200, files[id]);
        if (o.method == 'DELETE') {
          return (files.remove(id) == null ? 404 : 204, {});
        }
        return _tokens(o);
      });
      final auth = await _connected(adapter);
      DriveBackupClient client() =>
          DriveBackupClient(dio: _dio(adapter), auth: auth);
      final a = client(), b = client();
      final ra = (await a.download())!, rb = (await b.download())!;
      BackupBundle bundle(int id) => BackupBundle(
        watch: WatchSnapshot([
          ..._snapshot.entries,
          WatchEntry(
            title: fakeTitle(id),
            position: const Duration(minutes: 10),
            duration: const Duration(minutes: 90),
            updatedAt: DateTime.now(),
          ),
        ], {}),
        following: const FollowedSnapshot([], {}),
      );
      await Future.wait([
        a.upload(bundle(2), basedOn: ra.revision),
        b.upload(bundle(3), basedOn: rb.revision),
      ]);
      expect(files.keys, containsAll(['f1', 'f2']));
      final reader = client();
      final merged = (await reader.download())!;
      expect(merged.bundle.watch.entries.map((e) => e.id).toSet(), {
        'tt1',
        'tt2',
        'tt3',
      });
      await reader.upload(merged.bundle, basedOn: merged.revision);
      expect(files, hasLength(1));
      expect((await client().download())!.bundle.watch.entries, hasLength(3));
      expect(adapter.requests.any((r) => r.method == 'PATCH'), false);
    });

    test('will not overwrite a version it has not read', () async {
      final adapter = _Adapter(existing);
      final auth = await _connected(adapter);
      final client = DriveBackupClient(dio: _dio(adapter), auth: auth);
      await expectLater(
        client.upload(_bundle, basedOn: 'older'),
        throwsA(isA<BackupConflict>()),
      );
      expect(adapter.requests.any((r) => r.method == 'PATCH'), isFalse);
    });
  });
}
