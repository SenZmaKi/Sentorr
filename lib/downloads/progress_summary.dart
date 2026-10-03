import '../ui/shared/title_format.dart';
import 'models.dart';

/// Overall download progress, as the Android service notification and the
/// Windows taskbar show it; null when nothing is active.
class DownloadProgressSummary {
  const DownloadProgressSummary({
    required this.title,
    required this.text,
    required this.paused,
    this.progress,
    this.preparing = false,
  });
  final String title;
  final String text;

  /// Whether everything shown is paused, so the notification offers resume
  /// instead of pause.
  final bool paused;

  /// Fraction done; null while [preparing] or when sizes are unknown.
  final double? progress;

  /// Whether torrent sizes are still unknown.
  final bool preparing;

  /// Downloads still fetching data. Seeding ones are done and keep no
  /// service or taskbar progress up.
  static bool isDownloading(DownloadItem item) => switch (item.status) {
    DownloadStatus.preparing ||
    DownloadStatus.queued ||
    DownloadStatus.downloading => true,
    _ => false,
  };

  /// Summarizes downloading items, or the paused ones in [held] when
  /// nothing downloads.
  static DownloadProgressSummary? of(
    List<DownloadItem> items, {
    Set<String> held = const {},
  }) {
    final downloading = items.where(isDownloading).toList();
    if (downloading.isEmpty) {
      final paused = [
        for (final i in items)
          if (held.contains(i.id) && i.status == DownloadStatus.paused) i,
      ];
      if (paused.isEmpty) return null;
      return DownloadProgressSummary(
        title: _titleOf(paused, 'Paused'),
        text: '${_percent(_progressOf(paused))} · Paused',
        paused: true,
        progress: _progressOf(paused),
      );
    }
    final progress = _progressOf(downloading);
    final speed = downloading.fold(0.0, (s, i) => s + i.downloadBytesPerSecond);
    final waiting = downloading
        .where((i) => i.status == DownloadStatus.queued)
        .length;
    final seeding = items
        .where((i) => i.status == DownloadStatus.seeding)
        .length;
    return DownloadProgressSummary(
      title: _titleOf(downloading, 'Downloading'),
      text: [
        if (progress == null) 'Preparing' else _percent(progress),
        '${sizeLabel(speed.round())}/s',
        if (waiting > 0) '$waiting queued',
        if (seeding > 0) '$seeding seeding',
      ].join(' · '),
      paused: false,
      progress: progress,
      preparing: progress == null,
    );
  }

  static String _titleOf(List<DownloadItem> items, String verb) =>
      items.length == 1
      ? items.single.job.title
      : '$verb ${items.length} titles';

  static double? _progressOf(List<DownloadItem> items) {
    final total = items.fold(0, (s, i) => s + i.totalBytes);
    if (total == 0) return null;
    return items.fold(0, (s, i) => s + i.downloadedBytes) / total;
  }

  static String _percent(double? progress) =>
      progress == null ? '0%' : '${(progress * 100).floor()}%';
}
