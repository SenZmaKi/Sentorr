import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../following/auto_downloads.dart';
import '../../following/notifier.dart';
import '../../imdb/models.dart';
import '../../lists/models.dart';
import '../../lists/notifier.dart';
import '../../settings/models.dart';
import '../../settings/notifier.dart';
import '../shared/title_icons.dart';
import 'buttons.dart';
import 'menu.dart';

/// Puts [title] on one of the viewer's lists, or moves or takes it off.
/// Labelled with the list it is on. A series being watched also turns its
/// new-episode notifications and downloads on or off here.
class ListButton extends ConsumerWidget {
  const ListButton({super.key, required this.title});

  final ImdbTitle title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(watchStatusProvider(title.id));
    final lists = ref.read(watchListsProvider.notifier);
    return ActionMenu(
      title: title.title,
      actions: [
        for (final s in WatchStatus.values)
          MenuAction(
            s.label,
            icon: statusIcon(s),
            checked: s == status,
            stayOpen: false,
            onPressed: () => lists.set(title, s),
          ),
        if (status == WatchStatus.watching) ..._episodeActions(ref),
        if (status != null)
          MenuAction(
            'Remove from lists',
            icon: Icons.close_rounded,
            destructive: true,
            onPressed: () => lists.set(title, null),
          ),
      ],
      builder: (context, menu) => SButton(
        label: status?.label ?? 'Add to list',
        icon: status == null ? Icons.bookmark_add_outlined : statusIcon(status),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }

  List<MenuAction> _episodeActions(WidgetRef ref) {
    final followed = ref.watch(followedProvider(title.id));
    if (followed == null) return const [];
    final mode = ref.watch(
      settingsProvider.select((s) => s.following.autoDownload),
    );
    final notifier = ref.read(followedSeriesProvider.notifier);
    final downloads = ref.read(autoDownloadsProvider).enabledFor(followed);
    return [
      MenuAction(
        'Notify about new episodes',
        checked: followed.notify,
        onPressed: () => notifier.setNotify(title.id, !followed.notify),
      ),
      if (mode != AutoDownload.off)
        MenuAction(
          'Download new episodes',
          checked: downloads,
          onPressed: () async {
            await notifier.setAutoDownload(title.id, !downloads);
            if (!downloads) {
              unawaited(ref.read(autoDownloadsProvider).check(title.id));
            }
          },
        ),
    ];
  }
}
