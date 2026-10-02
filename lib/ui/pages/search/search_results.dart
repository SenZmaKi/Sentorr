import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../search/notifier.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/cards/card_skeleton.dart';
import '../../components/cards/poster_card.dart';
import '../../components/cards/title_poster.dart';
import '../../components/load_error.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_route.dart';

/// Poster grid of results: skeletons while the first page loads, more
/// skeletons while the next page loads, and plain-language empty and
/// failure states in the same rhythm.
class SearchResults extends ConsumerWidget {
  const SearchResults({super.key});

  // Nominal tile width; columns grow from it to fill the row.
  static const _tileWidth = 176.0;
  static const _gap = Space.s16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(searchProvider.select((s) => s.results));
    final search = ref.read(searchProvider.notifier);
    if (!r.loading && r.items.isEmpty) {
      return SliverToBoxAdapter(
        child: r.error != null
            ? Padding(
                padding: const EdgeInsets.only(top: Space.s24),
                child: LoadError(
                  message: "Couldn't search. Check your connection.",
                  onRetry: search.retry,
                ),
              )
            : const _NoResults(),
      );
    }
    final lines = CardLines(MediaQuery.textScalerOf(context));
    return SliverLayoutBuilder(
      builder: (context, box) {
        final width = box.crossAxisExtent;
        final columns = ((width + _gap) / (_tileWidth + _gap)).floor().clamp(
          2,
          12,
        );
        final tile = (width - _gap * (columns - 1)) / columns;
        final skeletons = r.loading
            ? columns * 3
            : r.loadingMore
            ? columns
            : 0;
        return SliverMainAxisGroup(
          slivers: [
            SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: _gap,
                mainAxisSpacing: Space.s24,
                mainAxisExtent: tile * 3 / 2 + PosterCard.textHeight(lines),
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => i < r.items.length
                    ? titlePoster(
                        r.items[i],
                        onOpen: () => ref.openTitle(r.items[i]),
                        onPlay: playPending,
                      )
                    : const CardSkeleton(aspectRatio: 2 / 3),
                childCount: r.items.length + skeletons,
              ),
            ),
            if (r.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: Space.s24),
                  child: LoadError(
                    message: "Couldn't load more results.",
                    onRetry: search.retry,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NoResults extends ConsumerWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final filtered =
        ref.watch(searchProvider.select((s) => s.query.filterCount)) > 0;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s64),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: c.foregroundMuted),
          const SizedBox(height: Space.s12),
          Text(
            'No titles found',
            textAlign: TextAlign.center,
            style: context.type.subtitle.copyWith(color: c.foreground),
          ),
          const SizedBox(height: Space.s4),
          Text(
            filtered
                ? 'Try another spelling or fewer filters.'
                : 'Try another spelling or a shorter title.',
            textAlign: TextAlign.center,
            style: context.type.bodySmall.copyWith(
              color: c.foregroundSecondary,
            ),
          ),
          if (filtered) ...[
            const SizedBox(height: Space.s16),
            SButton(
              label: 'Clear filters',
              icon: Icons.filter_alt_off_outlined,
              onPressed: () => ref
                  .read(searchProvider.notifier)
                  .update((q) => q.withoutFilters()),
            ),
          ],
        ],
      ),
    );
  }
}
