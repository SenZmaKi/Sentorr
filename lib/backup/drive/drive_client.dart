import 'package:dio/dio.dart';

import '../backup_bundle.dart';
import '../remote.dart';
import 'drive_auth.dart';

/// Immutable snapshots in Drive's app-data folder, compacted after publishing.
class DriveBackupClient implements BackupRemote {
  DriveBackupClient({
    required this.dio,
    required this.auth,
    this.api = 'https://www.googleapis.com',
  });

  static const fileName = 'sentorr-backup.json';
  static const _boundary = 'sentorr-backup-boundary';

  final Dio dio;
  final DriveAuth auth;
  final String api;

  List<String> _observed = const [];
  String? _revision;

  @override
  Future<RemoteBackup?> download() async {
    // A compactor may remove a listed snapshot after publishing its successor.
    for (var attempt = 0; attempt < 3; attempt++) {
      final files = await _files();
      BackupBundle? merged;
      try {
        for (final id in files) {
          final response = await _send<String>(
            'GET',
            '$api/drive/v3/files/$id',
            query: {'alt': 'media'},
            type: ResponseType.plain,
          );
          final bundle = BackupBundle.decode(response.data ?? '');
          merged = merged == null
              ? bundle
              : BackupBundle(
                  watch: merged.watch.merge(bundle.watch, capacity: 100),
                  following: merged.following.merge(bundle.following),
                );
        }
      } on DioException catch (error) {
        if (error.response?.statusCode == 404) continue;
        rethrow;
      }
      _observed = files;
      _revision = files.isEmpty ? null : files.join(',');
      return merged == null ? null : RemoteBackup(merged, _revision);
    }
    throw const BackupConflict();
  }

  @override
  Future<void> upload(BackupBundle bundle, {required String? basedOn}) async {
    if (basedOn != _revision) throw const BackupConflict();
    final covered = List<String>.of(_observed);
    // Publish a new immutable snapshot before removing only the snapshots
    // this writer read. Concurrent writers never delete each other's new work.
    await _send<void>(
      'POST',
      '$api/upload/drive/v3/files',
      query: {'uploadType': 'multipart'},
      body:
          '--$_boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '{"name":"$fileName","parents":["appDataFolder"]}\r\n'
          '--$_boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '${bundle.encode()}\r\n'
          '--$_boundary--',
      contentType: 'multipart/related; boundary=$_boundary',
    );
    for (final id in covered) {
      try {
        await _send<void>('DELETE', '$api/drive/v3/files/$id');
      } on DioException {
        // Cleanup is optional; redundant snapshots are safe to merge again.
      }
    }
    _observed = const [];
    _revision = null;
  }

  Future<List<String>> _files() async {
    final ids = <String>[];
    String? page;
    do {
      final response = await _send<Map<String, dynamic>>(
        'GET',
        '$api/drive/v3/files',
        query: {
          'spaces': 'appDataFolder',
          'q': "name = '$fileName' and trashed = false",
          'fields': 'nextPageToken,files(id)',
          'pageSize': '1000',
          'pageToken': ?page,
        },
      );
      final files = response.data?['files'];
      if (files is List) {
        for (final file in files) {
          if (file case {'id': final String id}) {
            ids.add(id);
          }
        }
      }
      page = response.data?['nextPageToken'] as String?;
    } while (page != null);
    return ids..sort();
  }

  /// Sends with the viewer's token, retrying once on a fresh one if Google
  /// says it ran out.
  Future<Response<T>> _send<T>(
    String method,
    String url, {
    Map<String, String>? query,
    String? body,
    String? contentType,
    ResponseType? type,
  }) async {
    Future<Response<T>> attempt(String token) => dio.request<T>(
      url,
      queryParameters: query,
      data: body,
      options: Options(
        method: method,
        contentType: contentType,
        responseType: type,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    try {
      return await attempt(await auth.accessToken());
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
      return attempt(await auth.refresh());
    }
  }
}
