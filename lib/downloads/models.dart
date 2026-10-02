import 'dart:convert';
import 'dart:typed_data';

enum DownloadStatus {
  queued,
  downloading,
  seeding,
  paused,
  completed,
  failed,
  cancelled,
}

extension DownloadStatusTerminal on DownloadStatus {
  bool get isTerminal =>
      this == DownloadStatus.completed ||
      this == DownloadStatus.failed ||
      this == DownloadStatus.cancelled;
}

/// Prepared torrent metadata, matching Senpwai's torrent enqueue boundary.
/// File indices are in torrent order; an empty selection means all files.
class TorrentDownloadJob {
  TorrentDownloadJob({
    required this.title,
    required Uint8List torrentData,
    required this.destinationDirectory,
    List<int> selectedFileIndices = const [],
    Map<int, String> renamedFiles = const {},
  }) : torrentData = Uint8List.fromList(torrentData),
       selectedFileIndices = List.unmodifiable(selectedFileIndices),
       renamedFiles = Map.unmodifiable(renamedFiles);
  final String title;
  final Uint8List torrentData;
  final String destinationDirectory;
  final List<int> selectedFileIndices;
  final Map<int, String> renamedFiles;

  Map<String, dynamic> toJson() => {
    'title': title,
    'torrent': base64Encode(torrentData),
    'directory': destinationDirectory,
    'selection': selectedFileIndices,
    'renames': {for (final e in renamedFiles.entries) '${e.key}': e.value},
  };
  factory TorrentDownloadJob.fromJson(Map<String, dynamic> json) =>
      TorrentDownloadJob(
        title: json['title'] as String,
        torrentData: base64Decode(json['torrent'] as String),
        destinationDirectory: json['directory'] as String,
        selectedFileIndices: (json['selection'] as List).cast<int>(),
        renamedFiles: (json['renames'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(int.parse(key), value as String),
        ),
      );
}

class DownloadFileProgress {
  const DownloadFileProgress(
    this.index,
    this.path,
    this.totalBytes,
    this.downloadedBytes,
  );
  final int index;
  final String path;
  final int totalBytes;
  final int downloadedBytes;
}

class DownloadItem {
  DownloadItem({
    required this.id,
    required this.job,
    this.status = DownloadStatus.queued,
    this.files = const [],
    this.downloadBytesPerSecond = 0,
    this.uploadBytesPerSecond = 0,
    this.uploadedBytes = 0,
    this.peers = 0,
    this.seeds = 0,
    this.error,
    this.seedingStartedAt,
  });
  final String id;
  final TorrentDownloadJob job;
  final DownloadStatus status;
  final List<DownloadFileProgress> files;
  final double downloadBytesPerSecond;
  final double uploadBytesPerSecond;
  final int uploadedBytes;
  final int peers;
  final int seeds;
  final String? error;
  final DateTime? seedingStartedAt;
  int get totalBytes => files.fold(0, (sum, f) => sum + f.totalBytes);
  int get downloadedBytes => files.fold(0, (sum, f) => sum + f.downloadedBytes);
  double get progress =>
      totalBytes == 0 ? 0 : (downloadedBytes / totalBytes).clamp(0, 1);

  DownloadItem withStatus(DownloadStatus value, {String? error}) =>
      DownloadItem(
        id: id,
        job: job,
        status: value,
        files: files,
        uploadedBytes: uploadedBytes,
        peers: peers,
        seeds: seeds,
        error: error,
        seedingStartedAt: seedingStartedAt,
      );
}

enum SeedingMode { disabled, limited, indefinitely }

/// Limits apply to this download session, independently of playback.
class DownloadSettings {
  const DownloadSettings({
    this.maxActiveDownloads = 2,
    this.maxActiveSeeds = 2,
    this.downloadBytesPerSecond = 0,
    this.uploadBytesPerSecond = 0,
    this.maxConnections = 200,
    this.seedingMode = SeedingMode.disabled,
    this.seedRatio = 1,
    this.seedTime = const Duration(minutes: 30),
    this.enableDht = true,
    this.enableLsd = true,
    this.enableUpnp = true,
    this.enableNatPmp = true,
  });
  final int maxActiveDownloads;
  final int maxActiveSeeds;
  final int downloadBytesPerSecond;
  final int uploadBytesPerSecond;
  final int maxConnections;
  final SeedingMode seedingMode;
  final double seedRatio;
  final Duration seedTime;
  final bool enableDht, enableLsd, enableUpnp, enableNatPmp;
  void validate() {
    if (maxActiveDownloads < 1 ||
        maxActiveSeeds < 1 ||
        downloadBytesPerSecond < 0 ||
        uploadBytesPerSecond < 0 ||
        maxConnections < 1 ||
        !seedRatio.isFinite ||
        seedRatio < 0 ||
        seedTime.isNegative) {
      throw ArgumentError('Invalid torrent download limits');
    }
  }
}
