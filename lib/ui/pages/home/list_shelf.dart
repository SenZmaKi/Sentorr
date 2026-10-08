import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../lists/models.dart';
import '../../../lists/notifier.dart';
import '../../components/app_shell.dart';
import '../../components/buttons.dart';
import '../../components/cards/title_poster.dart';
import '../../shared/play_route.dart';
import '../../shared/title_icons.dart';
import '../../shared/title_route.dart';
import '../lists/list_sections.dart';
import 'async_shelf.dart';
import 'home_layout.dart';

/// The titles on one of the viewer's lists, most recently changed first;
/// nothing while the list is empty. "See all" opens it on the Lists page.
class ListShelf extends ConsumerWidget {
  const ListShelf(this.status, {super.key});

  final WatchStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titles = ref.watch(
      watchListsProvider.select(
        (all) => [
          for (final e in all)
            if (e.status == status) e.title,
        ],
      ),
    );
    return AsyncShelf<ImdbTitle>(
      icon: statusIcon(status),
      title: status.label,
      count: (n) => n == 1 ? '1 title' : '$n titles',
      items: AsyncData(titles),
      spec: HomeLayout.of(context).poster,
      onRetry: () {},
      action: SButton.ghost(
        label: 'See all',
        onPressed: () {
          ref.read(listsSectionProvider.notifier).pick(ListsSection.of(status));
          ref.read(appDestinationProvider.notifier).go(AppDestination.lists);
        },
      ),
      cardBuilder: (context, t, _) => titlePoster(
        t,
        onOpen: () => ref.openTitle(t),
        onPlay: () => ref.playOrPickUp(t),
      ),
    );
  }
}
