import '../stream/stream_status.dart';

/// Uses unrounded container-indexed coverage, not the painted seek-bar spans.
/// Null means there is no authoritative timeline yet, not missing content.
bool? previewAvailableAt(StreamStatus? status, Duration target) {
  if (status == null) return null;
  if (status.localFile != null && status.peer == null) return true;
  final transfer = status.transfer;
  final size = transfer.selectedFile?.length ?? 0;
  if (size > 0 && transfer.selectedBytes == size) return true;
  if (transfer.mediaDuration <= 0) return null;
  final second = target.inMilliseconds / 1000;
  return transfer.downloadedTimes.any(
    (range) => second >= range.start && second < range.end,
  );
}
