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
  final _Reply Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = handler(options);
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

    test('updates and downloads the existing file', () async {
      final adapter = _Adapter(existing);
      final auth = await _connected(adapter);
      final client = DriveBackupClient(dio: _dio(adapter), auth: auth);
      final held = (await client.download())!;
      expect(held.bundle.watch.entries.single.id, 'tt1');
      expect(held.revision, 'm1');
      await client.upload(_bundle, basedOn: held.revision);
      expect(adapter.requests.last.method, 'PATCH');
      expect(adapter.requests.last.path, endsWith('/upload/drive/v3/files/f1'));
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
