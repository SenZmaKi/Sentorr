import '../models.dart';

/// One independently seekable interval and all bytes needed to cover it.
class MediaInterval {
  const MediaInterval(this.start, this.end, this.bytes);
  final double start, end;
  final List<DownloadedRange> bytes;
}

typedef MediaTimeRange = ({double start, double end});

/// Container-derived timestamps, never inferred from proportional file offsets.
class MediaIndex {
  MediaIndex(this.duration, this.intervals);
  final double duration;
  final List<MediaInterval> intervals;

  List<MediaTimeRange> available(List<DownloadedRange> verified) {
    bool covered(DownloadedRange range) {
      var lo = 0, hi = verified.length;
      while (lo < hi) {
        final mid = (lo + hi) ~/ 2;
        if (verified[mid].end < range.end) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      return lo < verified.length &&
          verified[lo].start <= range.start &&
          verified[lo].end >= range.end;
    }

    final result = <MediaTimeRange>[];
    for (final interval in intervals) {
      if (!interval.bytes.every(covered)) continue;
      if (result.isNotEmpty && interval.start <= result.last.end + 0.001) {
        final last = result.removeLast();
        result.add((
          start: last.start,
          end: interval.end > last.end ? interval.end : last.end,
        ));
      } else {
        result.add((start: interval.start, end: interval.end));
      }
    }
    return List.unmodifiable(result);
  }
}
