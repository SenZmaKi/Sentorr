import '../shared/persistence/json_file_store.dart';
import 'models.dart';

class DownloadRepository {
  DownloadRepository(this.store);
  final JsonFileStore store;
  final cancelledBatches = <String>{};
  final pausedBatches = <String>{};

  /// Unfinished downloads come back preparing; their torrents are re-added.
  Future<List<DownloadItem>> load() async {
    final json = await store.read();
    if (json == null) return [];
    cancelledBatches.addAll(
      (json['cancelledBatches'] as List? ?? []).cast<String>(),
    );
    pausedBatches.addAll((json['pausedBatches'] as List? ?? []).cast<String>());
    return [
      for (final raw in json['items'] as List)
        _decode(raw as Map<String, dynamic>),
    ];
  }

  DownloadItem _decode(Map<String, dynamic> json) {
    final status = DownloadStatus.values.byName(json['status'] as String);
    final started = DateTime.tryParse(json['seedStarted'] as String? ?? '');
    // Older versions replaced completed sharing records with engine failures
    // and recheck byte counts. Sharing only starts after every file completes.
    final recover = status == DownloadStatus.failed && started != null;
    return DownloadItem(
      id: json['id'] as String,
      job: TorrentDownloadJob.fromJson(json['job'] as Map<String, dynamic>),
      status: recover
          ? DownloadStatus.completed
          : status.isTerminal || status == DownloadStatus.paused
          ? status
          : DownloadStatus.preparing,
      infoHash: json['hash'] as String?,
      seedingStartedAt: started,
      error: recover ? null : json['error'] as String?,
      uploadedBytes: json['uploaded'] as int? ?? 0,
      files: List.unmodifiable([
        for (final f in json['files'] as List)
          DownloadFileProgress(
            f['index'] as int,
            f['path'] as String,
            f['size'] as int,
            started != null ? f['size'] as int : f['done'] as int,
          ),
      ]),
    );
  }

  Future<void> save(List<DownloadItem> items) => store.write({
    'version': 3,
    'cancelledBatches': cancelledBatches.toList(),
    'pausedBatches': pausedBatches.toList(),
    'items': [
      for (final i in items)
        {
          'id': i.id,
          'job': i.job.toJson(),
          'status': i.status.name,
          'hash': i.infoHash,
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
