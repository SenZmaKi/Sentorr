import 'package:flutter/foundation.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../../torrents/resolution_models.dart';

/// Where getting the current item's bytes to the player stands.
enum StreamStage {
  /// Searching for a torrent; the item came without one.
  finding,

  /// Fetching the torrent's file list from peers.
  connecting,

  /// Downloading the opening and closing pieces the player probes first.
  preparing,

  /// The player reads from the torrent.
  streaming,

  /// Reopening a previously playing peer before trying another source.
  reconnecting,

  /// A torrent failed; [StreamStatus.next] starts at [StreamStatus.retryAt]
  /// unless the viewer picks another or holds the switch.
  switching,
  failed,
}

/// Live torrent state for the current item, for the player's chrome.
@immutable
class StreamStatus {
  const StreamStatus({
    required this.stage,
    this.transfer = const TorrentStreamState(),
    this.torrent,
    this.problem,
    this.options,
    this.failed = const {},
    this.next,
    this.retryAt,
    this.localFile,
    this.peer,
    this.receivedAtStart = 0,
    this.uploadedAtStart = 0,
  });

  final StreamStage stage;
  final TorrentStreamState transfer;
  final TorrentCandidate? torrent;

  /// Why the last torrent could not start, in the viewer's terms.
  final String? problem;

  /// Everything found for the item, best first; null until searched.
  final TorrentResolution? options;

  /// Info hashes of torrents that already failed for this item.
  final Set<String> failed;

  /// While [StreamStage.switching]: the torrent tried next, and when.
  final TorrentCandidate? next;
  final DateTime? retryAt;

  /// The downloaded file playing instead of a torrent.
  final String? localFile;

  /// The paired device [localFile] plays from; null when it is this one's.
  final String? peer;

  /// Torrent lifetime counters when this playback attached to the transfer.
  final int receivedAtStart, uploadedAtStart;
  int get receivedBytes => (transfer.receivedBytes - receivedAtStart).clamp(
    0,
    transfer.receivedBytes,
  );
  int get uploadedBytes => (transfer.uploadedBytes - uploadedAtStart).clamp(
    0,
    transfer.uploadedBytes,
  );

  /// A resolved index remains authoritative even when none of its bytes exist.
  bool get hasDownloadedTimeline =>
      localFile != null ||
      (transfer.selectedFile != null &&
          transfer.selectedFile!.length > 0 &&
          transfer.selectedBytes == transfer.selectedFile!.length) ||
      transfer.mediaDuration > 0;

  /// Container-indexed time fractions; unknown regions remain empty.
  List<({double start, double end})> get downloadedSpans {
    if (localFile != null) return const [(start: 0.0, end: 1.0)];
    final fileLength = transfer.selectedFile?.length ?? 0;
    if (fileLength > 0 && transfer.selectedBytes == fileLength) {
      return const [(start: 0.0, end: 1.0)];
    }
    final length = transfer.mediaDuration;
    if (length <= 0) return const [];
    final ranges = transfer.downloadedTimes;
    if (ranges.length <= 512) {
      return List.unmodifiable([
        for (final range in ranges)
          (start: range.start / length, end: range.end / length),
      ]);
    }
    // Bound painting for pathological fragmentation. Keep only fully covered
    // bins, so reducing display detail never fills an undownloaded gap.
    final spans = <({double start, double end})>[];
    for (final range in ranges) {
      final start = (range.start * 512 / length).ceil() / 512;
      final end = (range.end * 512 / length).floor() / 512;
      if (end > start) spans.add((start: start, end: end));
    }
    return List.unmodifiable(spans);
  }

  bool get starting =>
      stage == StreamStage.finding ||
      stage == StreamStage.connecting ||
      stage == StreamStage.preparing ||
      stage == StreamStage.reconnecting;

  StreamStatus copyWith({
    StreamStage? stage,
    TorrentStreamState? transfer,
    TorrentCandidate? torrent,
    int? receivedAtStart,
    int? uploadedAtStart,
    String? problem,
    TorrentResolution? options,
    Set<String>? failed,
  }) {
    final resolved = stage ?? this.stage;
    return StreamStatus(
      stage: resolved,
      transfer: transfer ?? this.transfer,
      torrent: torrent ?? this.torrent,
      problem: problem ?? this.problem,
      options: options ?? this.options,
      failed: failed ?? this.failed,
      // Only a switch carries these; leaving it drops them.
      next: resolved == StreamStage.switching ? next : null,
      retryAt: resolved == StreamStage.switching ? retryAt : null,
      localFile: localFile,
      peer: peer,
      receivedAtStart: receivedAtStart ?? this.receivedAtStart,
      uploadedAtStart: uploadedAtStart ?? this.uploadedAtStart,
    );
  }

  StreamStatus switching(TorrentCandidate next, DateTime at) => StreamStatus(
    stage: StreamStage.switching,
    torrent: torrent,
    problem: problem,
    options: options,
    failed: failed,
    next: next,
    retryAt: at,
  );
}
