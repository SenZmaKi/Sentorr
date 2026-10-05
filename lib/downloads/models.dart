import 'dart:convert';
import 'dart:typed_data';

import 'package:torrent_stream/torrent_stream.dart';

enum DownloadStatus {
  /// Waiting for the torrent's metadata.
  preparing,
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

/// What to download: a magnet or torrent metadata, and which of its files.
/// File indices are in torrent order; an empty selection means all files.
/// Renames are relative to [destinationDirectory].
class TorrentDownloadJob {
  TorrentDownloadJob({
    required this.title,
    required this.destinationDirectory,
    this.batchId,
    this.magnet,
    Uint8List? torrentData,
    List<int> selectedFileIndices = const [],
    Map<int, String> renamedFiles = const {},
  }) : torrentData = torrentData == null
           ? null
           : Uint8List.fromList(torrentData),
       selectedFileIndices = List.unmodifiable(selectedFileIndices),
       renamedFiles = Map.unmodifiable(renamedFiles) {
    if ((magnet == null) == (torrentData == null)) {
      throw ArgumentError('A download needs a magnet or torrent metadata');
    }
  }
  final String title;
  final String? batchId;
  final Uri? magnet;
  final Uint8List? torrentData;
  final String destinationDirectory;
  final List<int> selectedFileIndices;
  final Map<int, String> renamedFiles;

  TorrentSource get source => magnet != null
      ? TorrentSource.magnet(magnet!)
      : TorrentSource.metadata(torrentData!);

  Map<String, dynamic> toJson() => {
    'title': title,
    if (batchId != null) 'batch': batchId,
    if (magnet != null) 'magnet': magnet.toString(),
    if (torrentData != null) 'torrent': base64Encode(torrentData!),
    'directory': destinationDirectory,
    'selection': selectedFileIndices,
    'renames': {for (final e in renamedFiles.entries) '${e.key}': e.value},
  };
  factory TorrentDownloadJob.fromJson(Map<String, dynamic> json) =>
      TorrentDownloadJob(
        title: json['title'] as String,
        batchId: json['batch'] as String?,
        magnet: switch (json['magnet']) {
          final String m => Uri.parse(m),
          _ => null,
        },
        torrentData: switch (json['torrent']) {
          final String t => base64Decode(t),
          _ => null,
        },
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
    this.status = DownloadStatus.preparing,
    this.infoHash,
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

  /// Known once the torrent is in the engine.
  final String? infoHash;
  final List<DownloadFileProgress> files;
  final double downloadBytesPerSecond;
  final double uploadBytesPerSecond;
  final int uploadedBytes;
  final int peers;
  final int seeds;
  final String? error;
  final DateTime? seedingStartedAt;

  /// Stable owner prefix; preparation appends its unique attempt number.
  String get owner => 'download:$id';
  int get totalBytes => files.fold(0, (sum, f) => sum + f.totalBytes);
  int get downloadedBytes => files.fold(0, (sum, f) => sum + f.downloadedBytes);
  double get progress =>
      totalBytes == 0 ? 0 : (downloadedBytes / totalBytes).clamp(0, 1);
  bool get isDone =>
      files.isNotEmpty && files.every((f) => f.downloadedBytes >= f.totalBytes);

  DownloadItem copyWith({
    DownloadStatus? status,
    String? infoHash,
    List<DownloadFileProgress>? files,
    double? downloadBytesPerSecond,
    double? uploadBytesPerSecond,
    int? uploadedBytes,
    int? peers,
    int? seeds,
    DateTime? seedingStartedAt,
    String? error,
    bool clearError = false,
  }) => DownloadItem(
    id: id,
    job: job,
    status: status ?? this.status,
    infoHash: infoHash ?? this.infoHash,
    files: files ?? this.files,
    downloadBytesPerSecond:
        downloadBytesPerSecond ?? this.downloadBytesPerSecond,
    uploadBytesPerSecond: uploadBytesPerSecond ?? this.uploadBytesPerSecond,
    uploadedBytes: uploadedBytes ?? this.uploadedBytes,
    peers: peers ?? this.peers,
    seeds: seeds ?? this.seeds,
    seedingStartedAt: seedingStartedAt ?? this.seedingStartedAt,
    error: clearError ? null : error ?? this.error,
  );

  /// At [value], with transfer rates cleared unless still transferring.
  DownloadItem withStatus(DownloadStatus value, {String? error}) {
    final moving =
        value == DownloadStatus.downloading || value == DownloadStatus.seeding;
    return DownloadItem(
      id: id,
      job: job,
      status: value,
      infoHash: infoHash,
      files: files,
      downloadBytesPerSecond: moving ? downloadBytesPerSecond : 0,
      uploadBytesPerSecond: moving ? uploadBytesPerSecond : 0,
      uploadedBytes: uploadedBytes,
      peers: moving ? peers : 0,
      seeds: moving ? seeds : 0,
      error: error,
      seedingStartedAt: seedingStartedAt,
    );
  }
}

enum SeedingMode { disabled, limited, indefinitely }

/// Queue policy. Bandwidth, connections and discovery belong to the torrent
/// engine, shared with streaming.
class DownloadSettings {
  const DownloadSettings({
    this.maxActiveDownloads = 2,
    this.maxActiveSeeds = 5,
    this.seedingMode = SeedingMode.limited,
    this.seedRatio = 2,
    this.seedTime = const Duration(hours: 24),
    this.pauseWhileStreaming = true,
  });
  final int maxActiveDownloads;
  final int maxActiveSeeds;
  final SeedingMode seedingMode;
  final double seedRatio;
  final Duration seedTime;

  /// Leave the bandwidth to playback: downloads other than the one being
  /// watched wait while anything streams.
  final bool pauseWhileStreaming;
  void validate() {
    if (maxActiveDownloads < 1 ||
        maxActiveSeeds < 1 ||
        !seedRatio.isFinite ||
        seedRatio < 0 ||
        seedTime.isNegative) {
      throw ArgumentError('Invalid download queue limits');
    }
  }
}
