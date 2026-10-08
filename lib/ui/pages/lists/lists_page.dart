import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../lists/models.dart';
import '../../../lists/notifier.dart';
import '../../components/content_column.dart';
import '../../shared/layout/layout_size.dart';
import '../../shared/theme/theme.dart';
import '../home/home_layout.dart';
import '../home/continue_shelf.dart';
import 'list_grid.dart';
import 'list_rail.dart';
import 'list_sections.dart';
import 'new_episodes_panel.dart';

/// The viewer's lists down a rail, like a library, with the chosen one
/// beside it; Watching leads with what can be picked back up. Compact
/// windows put the sections in tabs above instead.
class ListsPage extends ConsumerWidget {
  const ListsPage({super.key});

  /// Rail, gap and grid together: the width of Settings' sidebar and
  /// page, so both sidebars line up when switching between them.
  static const _maxWidth = 1064.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, box) {
        final insets = ContentInsets(box.maxWidth);
        if (LayoutSize(box.biggest).compact) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: insets.side,
              vertical: insets.gutter,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTabs(),
                SizedBox(height: Space.s24),
                _Section(),
              ],
            ),
          );
        }
        // As Settings: the rail and its list centre as one block under a
        // cap, clear of the navigation, instead of hugging the left edge.
        final layout = LayoutSize(box.biggest);
        final rail = layout.pick(compact: 200.0, expanded: ListRail.width);
        final gap = layout.pick(compact: Space.s24, expanded: Space.s32);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            insets.gutter,
            insets.gutter,
            insets.gutter,
            0,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: rail, child: const ListRail()),
                  SizedBox(width: gap),
                  const Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: Space.s24),
                      child: _Section(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Section extends ConsumerWidget {
  const _Section();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(listsSectionProvider).status;
    if (status == null) return const NewEpisodesPanel();
    final entries = [
      for (final e in ref.watch(watchListsProvider))
        if (e.status == status) e,
    ];
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (status == WatchStatus.watching)
            // Sized like Home's, so the cards read the same in both.
            HomeLayout(
              layout: LayoutSize(Size(box.maxWidth, 0)),
              textScaler: MediaQuery.textScalerOf(context),
              child: const Padding(
                padding: EdgeInsets.only(bottom: Space.s24),
                child: ContinueWatchingShelf(gutter: 0, top: 0, editable: true),
              ),
            ),
          ListGrid(status: status, entries: entries),
        ],
      ),
    );
  }
}
