import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../imdb/models.dart';
import '../../lists/models.dart';
import '../../lists/notifier.dart';
import '../shared/theme/theme.dart';
import '../shared/title_icons.dart';
import 'artwork_frame.dart';
import 'buttons.dart';

/// Stamp on a title's artwork naming the list it is on; nothing when it is
/// on none. [compact] shows only the icon, for posters that also carry a
/// rating.
class ListBadge extends ConsumerWidget {
  const ListBadge({super.key, required this.titleId, this.compact = false});

  final String titleId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(watchStatusProvider(titleId));
    if (status == null) return const SizedBox.shrink();
    if (!compact) return OverlayBadge(status.label, icon: statusIcon(status));
    return Tooltip(
      message: status.label,
      child: Semantics(
        label: status.label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: OverlayColors.controlSurface,
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.s4),
            child: Icon(
              statusIcon(status),
              size: 14,
              color: OverlayColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

/// One-tap Plan to watch for places a menu cannot live, e.g. a hover
/// preview: adds [title] when it is on no list and takes it back off Plan
/// to watch. On any other list it shows which, and [onOpen] goes where
/// that can change.
class PlanToggle extends ConsumerWidget {
  const PlanToggle({super.key, required this.title, required this.onOpen});

  final ImdbTitle title;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(watchStatusProvider(title.id));
    final lists = ref.read(watchListsProvider.notifier);
    return switch (status) {
      null => SIconButton(
        icon: Icons.bookmark_add_outlined,
        tooltip: 'Plan to watch',
        onPressed: () => lists.set(title, WatchStatus.planned),
      ),
      WatchStatus.planned => SIconButton(
        icon: Icons.bookmark_rounded,
        tooltip: 'Remove from Plan to watch',
        selected: true,
        onPressed: () => lists.set(title, null),
      ),
      final s => SIconButton(
        icon: statusIcon(s),
        tooltip: '${s.label}. Open to change',
        selected: true,
        onPressed: onOpen,
      ),
    };
  }
}
