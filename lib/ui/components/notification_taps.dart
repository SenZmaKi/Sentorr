import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../following/notifier.dart';
import '../../notifications/notification_service.dart';
import '../shared/title_route.dart';
import 'app_shell.dart';
import '../shared/window_manager.dart';

/// Brings Sentorr forward on what a clicked notification is about.
class NotificationTaps extends ConsumerStatefulWidget {
  const NotificationTaps({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<NotificationTaps> createState() => _NotificationTapsState();
}

class _NotificationTapsState extends ConsumerState<NotificationTaps> {
  late final StreamSubscription<NotificationTarget> _taps;

  @override
  void initState() {
    super.initState();
    _taps = ref.read(notificationServiceProvider).taps.listen(_open);
  }

  void _open(NotificationTarget target) {
    unawaited(WindowManager.getInstance().focus());
    switch (target) {
      case SeriesTarget(:final seriesId):
        final followed = ref
            .read(followedSeriesProvider)
            .where((s) => s.id == seriesId)
            .firstOrNull;
        if (followed != null) ref.openTitle(followed.series);
      case DownloadsTarget():
        ref.read(appDestinationProvider.notifier).go(AppDestination.downloads);
    }
  }

  @override
  void dispose() {
    unawaited(_taps.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
