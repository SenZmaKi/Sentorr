import '../shared/persistence/json_file_store.dart';
import 'models.dart';

class DownloadRepository {
  DownloadRepository(this.store);
  final JsonFileStore store;

  Future<List<DownloadItem>> load() async {
    final json = await store.read();
    if (json == null) return [];
    return [
      for (final raw in json['items'] as List)
        _decode(raw as Map<String, dynamic>),
    ];
  }

  DownloadItem _decode(Map<String, dynamic> json) {
    final status = DownloadStatus.values.byName(json['status'] as String);
    return DownloadItem(
      id: json['id'] as String,
      job: TorrentDownloadJob.fromJson(json['job'] as Map<String, dynamic>),
      status: status.isTerminal || status == DownloadStatus.paused
          ? status
          : DownloadStatus.queued,
      seedingStartedAt: DateTime.tryParse(json['seedStarted'] as String? ?? ''),
      error: json['error'] as String?,
      uploadedBytes: json['uploaded'] as int? ?? 0,
      files: List.unmodifiable([
        for (final f in json['files'] as List)
          DownloadFileProgress(
            f['index'] as int,
            f['path'] as String,
            f['size'] as int,
            f['done'] as int,
          ),
      ]),
    );
  }

  Future<void> save(List<DownloadItem> items) => store.write({
    'version': 1,
    'items': [
      for (final i in items)
        {
          'id': i.id,
          'job': i.job.toJson(),
          'status': i.status.name,
          'seedStarted': i.seedingStartedAt?.toIso8601String(),
          'uploaded': i.uploadedBytes,
          'error': i.error,
          'files': [
            for (final f in i.files)
              {
                'index': f.index,
                'path': f.path,
                'size': f.totalBytes,
                'done': f.downloadedBytes,
              },
          ],
        },
    ],
  });
}
