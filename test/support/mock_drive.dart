import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sentorr/backup/backup_bundle.dart';
import 'package:sentorr/backup/drive/drive_auth.dart';
import 'package:sentorr/backup/drive/drive_client.dart';

/// Shared app-data storage. Each simulated device gets its own real Drive
/// client, auth and HTTP adapter; only the remote file store is shared.
class MockDriveRepository {
  final files = <String, String>{};
  final deleted = <String>[];
  int uploads = 0;
  bool failUploads = false;
  int _sequence = 0;
  int _waiting = 0;
  int _participants = 0;
  Completer<void>? _barrier;

  /// Makes the next clients list the same snapshots before any can publish.
  void synchronizeReads(int participants) {
    _waiting = 0;
    _participants = participants;
    _barrier = Completer<void>();
  }

  DriveBackupClient client() {
    final dio = Dio()..httpClientAdapter = _DriveAdapter(this);
    return DriveBackupClient(dio: dio, auth: MockDriveAuth(dio));
  }

  Future<(int, Object?)> request(RequestOptions request) async {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/drive/v3/files') {
      final listed = {
        'files': [
          for (final entry in files.entries)
            {
              'id': entry.key,
              'name': DriveBackupClient.fileName,
              'md5Checksum': entry.value,
            },
        ],
      };
      final barrier = _barrier;
      if (barrier != null) {
        if (++_waiting == _participants) {
          _barrier = null;
          barrier.complete();
        }
        await barrier.future.timeout(const Duration(seconds: 5));
      }
      return (200, listed);
    }
    if (request.method == 'POST' && path == '/upload/drive/v3/files') {
      if (failUploads) return (503, {'error': 'mock outage'});
      final body = (request.data as String)
          .split('\r\n\r\n')[2]
          .split('\r\n--')[0];
      BackupBundle.decode(body, strict: true);
      final id = 'snapshot-${++_sequence}';
      files[id] = body;
      uploads++;
      return (200, {'id': id});
    }
    final id = path.split('/').last;
    if (request.method == 'GET' && files.containsKey(id)) {
      return (200, files[id]);
    }
    if (request.method == 'DELETE') {
      deleted.add(id);
      return (files.remove(id) == null ? 404 : 204, {});
    }
    return (404, {'error': 'unknown mock endpoint'});
  }
}

class MockDriveAuth extends DriveAuth {
  MockDriveAuth(Dio dio) : super(dio: dio, openBrowser: (_) async => true);

  @override
  bool get connected => true;

  @override
  Future<String> accessToken() async => 'mock-token';
}

class _DriveAdapter implements HttpClientAdapter {
  _DriveAdapter(this.repository);
  final MockDriveRepository repository;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = await repository.request(options);
    return ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
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
