import 'dart:convert';

import 'package:logging/logging.dart';

import '../shared/persistence/json_file_store.dart';
import 'models.dart';

class DownloadRepository {
  DownloadRepository(this.store);
  final JsonFileStore store;
  final cancelledBatches = <String>{};
  final pausedBatches = <String>{};

  /// Unfinished downloads come back preparing; their torrents are re-added.
  Future<List<DownloadItem>> load() async {
    var json = await store.read();
    if (json == null) return [];
    final version = json['version'];
    if (version is! int || version < 1 || version > 3) {
      throw const FormatException('Unsupported saved download queue version');
    }
    if (json['items'] is! List) {
      await _preserve();
      if (!await store.backup.exists()) {
        throw const FormatException('Expected saved download items');
      }
      final recovered = jsonDecode(await store.backup.readAsString());
      if (recovered is! Map<String, dynamic> ||
          recovered['items'] is! List ||
          recovered['version'] is! int ||
          (recovered['version'] as int) < 1 ||
          (recovered['version'] as int) > 3) {
        throw const FormatException('Invalid saved download backup');
      }
      json = recovered;
    }
    final items = <DownloadItem>[];
    final rejected = <Object?>[];
    final ids = <String>{};
    final records = json['items'];
    if (records is! List) {
      await _preserve();
      throw const FormatException('Expected saved download items');
    }
    for (final raw in records) {
      try {
        final item = _decode(raw as Map<String, dynamic>);
        if (item.id.isEmpty || !ids.add(item.id)) {
          throw const FormatException('Invalid or duplicate download id');
        }
        items.add(item);
      } on Object catch (error, stack) {
        rejected.add(raw);
        Logger('sentorr.downloads')
            .warning('Rejected saved download', error, stack);
      }
    }
    List<String> batches(String field) {
      final value = json![field];
      if (value == null) return [];
      if (value is! List || value.any((e) => e is! String)) {
        rejected.add(value);
        return value is List ? value.whereType<String>().toList() : [];
      }
      return value.cast<String>();
    }

    cancelledBatches
      ..clear()
      ..addAll(batches('cancelledBatches'));
    pausedBatches
      ..clear()
      ..addAll(batches('pausedBatches'));
    if (rejected.isNotEmpty) await _preserve();
    return items;
  }

  Future<void> _preserve() async {
    final preserved =
        '${store.file.path}.${DateTime.now().microsecondsSinceEpoch}.rejected';
    await store.file.copy(preserved);
    Logger('sentorr.downloads')
        .warning('Preserved damaged queue at $preserved');
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
