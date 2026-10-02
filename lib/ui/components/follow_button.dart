import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../following/auto_downloads.dart';
import '../../following/notifier.dart';
import '../../imdb/models.dart';
import '../../settings/models.dart';
import '../../settings/notifier.dart';
import '../../shared/errors/error_reports.dart';
import 'buttons.dart';
import 'menu.dart';

/// Follows [series] for new episodes. Once followed, a menu turns its
/// notifications and auto-download on or off, or unfollows it.
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({super.key, required this.series});

  final ImdbTitle series;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _busy = false;

  Future<void> _follow() async {
    setState(() => _busy = true);
    try {
      await ref.read(followedSeriesProvider.notifier).follow(widget.series);
    } catch (error, stack) {
      ErrorReports.report(
        "Couldn't follow ${widget.series.title}",
        error,
        stack,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.series.id;
    final followed = ref.watch(followedProvider(id));
    final mode = ref.watch(
      settingsProvider.select((s) => s.following.autoDownload),
    );
    if (followed == null) {
      return Tooltip(
        message: 'Get told about new episodes',
        child: SButton(
          label: 'Follow',
          icon: Icons.add_rounded,
          loading: _busy,
          onPressed: _follow,
        ),
      );
    }
    final notifier = ref.read(followedSeriesProvider.notifier);
    final downloads = ref.read(autoDownloadsProvider).enabledFor(followed);
    return ActionMenu(
      actions: [
        MenuAction(
          'Notify about new episodes',
          checked: followed.notify,
          onPressed: () => notifier.setNotify(id, !followed.notify),
        ),
        if (mode != AutoDownload.off)
          MenuAction(
            'Download new episodes',
            checked: downloads,
            onPressed: () async {
              await notifier.setAutoDownload(id, !downloads);
              if (!downloads) {
                unawaited(ref.read(autoDownloadsProvider).check(id));
              }
            },
          ),
        MenuAction(
          'Unfollow',
          icon: Icons.close_rounded,
          destructive: true,
          onPressed: () => notifier.unfollow(id),
        ),
      ],
      builder: (context, menu) => SButton(
        label: 'Following',
        icon: downloads ? Icons.download_done_rounded : Icons.check_rounded,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}
