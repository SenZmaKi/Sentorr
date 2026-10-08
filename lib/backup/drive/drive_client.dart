import 'package:dio/dio.dart';

import '../../shared/parallel.dart';
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
  final _cache = <String, ({String checksum, BackupBundle bundle})>{};

  @override
  Future<RemoteBackup?> download() async {
    // A compactor may remove a listed snapshot after publishing its successor.
    for (var attempt = 0; attempt < 3; attempt++) {
      final files = await _files();
      BackupBundle? merged;
      try {
        _cache.removeWhere((id, _) => !files.containsKey(id));
        await auth.accessToken();
        final bundles = await parallelMapOrdered(
          files.keys,
          maxConcurrent: 4,
          operation: (id) async {
            final checksum = files[id];
            final cached = _cache[id];
            if (checksum != null && cached?.checksum == checksum) {
              return cached!.bundle;
            }
            final response = await _send<String>(
              'GET',
              '$api/drive/v3/files/$id',
              query: {'alt': 'media'},
              type: ResponseType.plain,
            );
            final bundle = BackupBundle.decode(response.data ?? '');
            if (checksum != null) {
              _cache[id] = (checksum: checksum, bundle: bundle);
            }
            return bundle;
          },
        );
        for (final bundle in bundles) {
          merged = merged == null
              ? bundle
              : BackupBundle(
                  watch: merged.watch.merge(bundle.watch, capacity: 100),
                  following: merged.following.merge(bundle.following),
                  lists: merged.lists.merge(bundle.lists),
                );
        }
      } on DioException catch (error) {
        if (error.response?.statusCode == 404) continue;
        rethrow;
      }
      _observed = files.keys.toList();
      _revision = files.isEmpty ? null : files.keys.join(',');
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
    await parallelMapOrdered(
      covered,
      maxConcurrent: 4,
      operation: (id) async {
        try {
          await _send<void>('DELETE', '$api/drive/v3/files/$id');
        } on DioException {
          // Cleanup is optional; redundant snapshots are safe to merge again.
        }
        _cache.remove(id);
      },
    );
    _observed = const [];
    _revision = null;
  }

  Future<Map<String, String?>> _files() async {
    final ids = <String, String?>{};
    String? page;
    do {
      final response = await _send<Map<String, dynamic>>(
        'GET',
        '$api/drive/v3/files',
        query: {
          'spaces': 'appDataFolder',
          'q': "name = '$fileName' and trashed = false",
          'fields': 'nextPageToken,files(id,md5Checksum)',
          'pageSize': '1000',
          'pageToken': ?page,
        },
      );
      final files = response.data?['files'];
      if (files is List) {
        for (final file in files) {
          if (file case {'id': final String id}) {
            ids[id] = file['md5Checksum'] as String?;
          }
        }
      }
      page = response.data?['nextPageToken'] as String?;
    } while (page != null);
    return {for (final id in ids.keys.toList()..sort()) id: ids[id]};
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
