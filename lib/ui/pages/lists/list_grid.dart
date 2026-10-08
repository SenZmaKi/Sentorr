import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../lists/models.dart';
import '../../components/cards/card_parts.dart';
import '../../components/cards/poster_card.dart';
import 'list_poster.dart';
import '../../shared/layout/adaptive.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_icons.dart';

/// Poster grid of one list's [entries], or a note on how to fill it.
class ListGrid extends ConsumerWidget {
  const ListGrid({super.key, required this.status, required this.entries});

  final WatchStatus status;
  final List<ListEntry> entries;

  // Matches the search grid so posters read the same size everywhere.
  static double _tileWidth(double width) =>
      LayoutSize(Size(width, 0))
          .pick(compact: 176.0, medium: 160.0, expanded: 176.0, large: 200.0);
  static const _gap = Space.s16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) return _Empty(status);
    final lines = CardLines(MediaQuery.textScalerOf(context));
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final columns = ((width + _gap) / (_tileWidth(width) + _gap))
            .floor()
            .clamp(2, 12);
        final tile = (width - _gap * (columns - 1)) / columns;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: _gap,
            mainAxisSpacing: Space.s24,
            mainAxisExtent: tile * 3 / 2 + PosterCard.textHeight(lines),
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) => ListPoster(entry: entries[i]),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.status);

  final WatchStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s64),
      child: Column(
        children: [
          Icon(statusIcon(status), size: 40, color: c.foregroundMuted),
          const SizedBox(height: Space.s12),
          Text(
            switch (status) {
              WatchStatus.watching => 'Nothing in progress',
              WatchStatus.rewatching => 'Nothing being rewatched',
              WatchStatus.completed => 'Nothing completed yet',
              _ => 'Nothing ${status.name}',
            },
            textAlign: TextAlign.center,
            style: context.type.subtitle.copyWith(color: c.foreground),
          ),
          const SizedBox(height: Space.s4),
          Text(
            switch (status) {
              WatchStatus.watching => 'Titles you play show up here.',
              WatchStatus.rewatching =>
                'Completed titles you play again show up here.',
              WatchStatus.completed =>
                'Finished movies and titles you mark completed show up here.',
              _ => 'Use Add to list on a title to put it here.',
            },
            textAlign: TextAlign.center,
            style: context.type.bodySmall.copyWith(
              color: c.foregroundSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
