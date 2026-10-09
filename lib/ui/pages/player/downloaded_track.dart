import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../player/stream/stream_status.dart';

/// Projects availability once per transfer event, outside position/paint updates.
class DownloadedTrack extends StatelessWidget {
  const DownloadedTrack({
    super.key,
    required this.status,
    required this.builder,
    required this.cached,
  });
  final ValueListenable<StreamStatus?> status;
  final ValueListenable<List<({double start, double end})>> cached;
  final Widget Function(BuildContext, List<({double start, double end})>)
  builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: status,
    builder: (context, value, _) {
      if (value?.hasDownloadedTimeline == true) {
        return builder(context, value!.downloadedSpans);
      }
      if (value?.stage != StreamStage.streaming) {
        return builder(context, const []);
      }
      return ValueListenableBuilder(
        valueListenable: cached,
        builder: (context, ranges, _) => builder(context, ranges),
      );
    },
  );
}
