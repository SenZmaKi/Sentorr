import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../search/models.dart';
import '../../../search/notifier.dart';
import '../../components/buttons.dart';
import '../../components/select.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// Result tally on the left; ordering and its direction on the right.
class SearchToolbar extends ConsumerWidget {
  const SearchToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(searchProvider);
    final q = state.query;
    final r = state.results;
    final search = ref.read(searchProvider.notifier);
    final count = r.total ?? r.items.length;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: r.loading
                ? Text(
                    'Searching…',
                    style: context.type.bodySmall.copyWith(
                      color: c.foregroundMuted,
                    ),
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: groupedCount(count),
                          style: context.type.technical.copyWith(
                            color: c.foreground,
                          ),
                        ),
                        TextSpan(text: count == 1 ? ' title' : ' titles'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodySmall.copyWith(
                      color: c.foregroundSecondary,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: Space.s12),
        SizedBox(
          width: 168,
          child: SSelect<ImdbSort>(
            options: ImdbSort.values,
            selected: {q.sort},
            labelOf: (s) => s.label,
            semanticLabel: 'Sort by',
            icon: Icons.sort_rounded,
            onSelected: search.sortBy,
          ),
        ),
        const SizedBox(width: Space.s4),
        SIconButton(
          icon: q.descending
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded,
          tooltip: q.descending ? 'Descending' : 'Ascending',
          onPressed: () =>
              search.update((q) => q.copyWith(descending: !q.descending)),
        ),
      ],
    );
  }
}
