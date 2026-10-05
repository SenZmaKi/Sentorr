import 'package:dio/dio.dart';

import '../backup_bundle.dart';
import '../remote.dart';
import 'drive_auth.dart';

/// Sentorr's one backup file in the viewer's hidden app-data folder.
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

  @override
  Future<RemoteBackup?> download() async {
    final file = await _file();
    if (file == null) return null;
    final response = await _send<String>(
      'GET',
      '$api/drive/v3/files/${file.id}',
      query: {'alt': 'media'},
      type: ResponseType.plain,
    );
    return RemoteBackup(
      BackupBundle.decode(response.data ?? ''),
      file.revision,
    );
  }

  @override
  Future<void> upload(BackupBundle bundle, {required String? basedOn}) async {
    final body = bundle.encode();
    final file = await _file();
    if (file?.revision != basedOn) throw const BackupConflict();
    if (file != null) {
      await _send<void>(
        'PATCH',
        '$api/upload/drive/v3/files/${file.id}',
        query: {'uploadType': 'media'},
        body: body,
        contentType: Headers.jsonContentType,
      );
      return;
    }
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
          '$body\r\n'
          '--$_boundary--',
      contentType: 'multipart/related; boundary=$_boundary',
    );
  }

  /// The oldest file of that name, so devices that raced to create it
  /// agree on one. Its checksum names the version.
  Future<({String id, String? revision})?> _file() async {
    final response = await _send<Map<String, dynamic>>(
      'GET',
      '$api/drive/v3/files',
      query: {
        'spaces': 'appDataFolder',
        'q': "name = '$fileName'",
        'fields': 'files(id,md5Checksum)',
        'orderBy': 'createdTime',
        'pageSize': '1',
      },
    );
    final files = response.data?['files'];
    if (files is List && files.isNotEmpty && files.first is Map) {
      final file = files.first as Map;
      return (
        id: file['id'] as String,
        revision: file['md5Checksum'] as String?,
      );
    }
    return null;
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
