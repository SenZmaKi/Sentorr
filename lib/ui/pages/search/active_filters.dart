import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../search/models.dart';
import '../../../search/notifier.dart';
import '../../components/buttons.dart';
import '../../components/chips.dart';
import '../../shared/theme/theme.dart';
import '../../components/range_field.dart';
import 'search_filters.dart';

/// "Rated 7–9", "Rated 7+", "Rated up to 5".
String boundsLabel(
  Bounds<num> b, {
  required String prefix,
  String suffix = '',
  String Function(num v)? from,
  String Function(num v)? until,
}) {
  final min = b.min, max = b.max;
  if (min != null && max != null) {
    return min == max
        ? '$prefix ${formatBound(min)}$suffix'
        : '$prefix ${formatBound(min)}–${formatBound(max)}$suffix';
  }
  if (min != null) {
    return from?.call(min) ?? '$prefix ${formatBound(min)}+$suffix';
  }
  return until?.call(max!) ?? '$prefix up to ${formatBound(max!)}$suffix';
}

/// One removable chip per active filter, so the whole query reads at a
/// glance even while the filter panel is closed.
class ActiveFilters extends ConsumerWidget {
  const ActiveFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(searchProvider.select((s) => s.query));
    final search = ref.read(searchProvider.notifier);
    if (q.filterCount == 0) return const SizedBox.shrink();
    SChip chip(String label, SearchQuery Function(SearchQuery q) remove) =>
        SChip(
          label: label,
          selected: true,
          removable: true,
          onTap: () => search.update(remove),
        );
    return Wrap(
      spacing: Space.s8,
      runSpacing: Space.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final g in q.genres)
          chip(g, (q) => q.copyWith(genres: toggled(q.genres, g))),
        for (final k in q.kinds)
          chip(k.label, (q) => q.copyWith(kinds: toggled(q.kinds, k))),
        if (!q.rating.isOpen)
          chip(
            boundsLabel(q.rating, prefix: 'Rated'),
            (q) => q.copyWith(rating: const Bounds()),
          ),
        if (!q.years.isOpen)
          chip(
            boundsLabel(
              q.years,
              prefix: 'Released',
              from: (v) => 'From $v',
              until: (v) => 'Until $v',
            ),
            (q) => q.copyWith(years: const Bounds()),
          ),
        if (!q.runtime.isOpen)
          chip(
            boundsLabel(
              q.runtime,
              prefix: 'Runs',
              suffix: ' min',
              from: (v) => 'Over $v min',
              until: (v) => 'Under $v min',
            ),
            (q) => q.copyWith(runtime: const Bounds()),
          ),
        SButton.ghost(
          label: 'Clear all',
          onPressed: () => search.update((q) => q.withoutFilters()),
        ),
      ],
    );
  }
}
