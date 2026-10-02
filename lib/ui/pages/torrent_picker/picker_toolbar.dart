import 'package:flutter/material.dart';

import '../../../torrents/filters.dart';
import '../../components/buttons.dart';
import '../../components/chips.dart';
import '../../components/range_field.dart';
import '../../components/select.dart';
import '../../shared/theme/theme.dart';

/// Order, then the filters toggle carrying how many are on.
class PickerToolbar extends StatelessWidget {
  const PickerToolbar({
    super.key,
    required this.filters,
    required this.filtersOpen,
    required this.onToggleFilters,
    required this.onChanged,
  });

  final TorrentFilters filters;
  final bool filtersOpen;
  final VoidCallback onToggleFilters;
  final ValueChanged<TorrentFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = filters.activeCount;
    final sort = SSelect<TorrentSort>(
      options: TorrentSort.values,
      selected: {filters.sort},
      labelOf: (s) => s.label,
      semanticLabel: 'Sort torrents',
      icon: Icons.sort_rounded,
      onSelected: (s) => onChanged(filters.copyWith(sort: s)),
    );
    final toggle = SButton(
      label: active == 0 ? 'Filters' : 'Filters · $active',
      icon: filtersOpen ? Icons.expand_less_rounded : Icons.tune_rounded,
      onPressed: onToggleFilters,
    );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < _sideBySide
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Space.s8,
              children: [
                sort,
                Align(alignment: Alignment.centerLeft, child: toggle),
              ],
            )
          : Row(
              spacing: Space.s8,
              children: [
                Expanded(child: sort),
                toggle,
              ],
            ),
    );
  }

  /// Below this the sort's label would be cut to nothing beside the toggle.
  static const _sideBySide = 360.0;
}

/// The filters in effect as removable chips, for when their controls are
/// folded away, and a way to drop them all.
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  final TorrentFilters filters;
  final ValueChanged<TorrentFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final f = filters;
    String names<T>(Set<T> set, String Function(T) label) =>
        set.map(label).join(', ');
    String gb(double? v) => v == null ? 'any' : '${formatBound(v)} GB';
    final chips = <(String, TorrentFilters)>[
      if (f.qualities.isNotEmpty)
        (names(f.qualities, (q) => q.label), f.copyWith(qualities: const {})),
      if (f.origins.isNotEmpty)
        (names(f.origins, (o) => o.label), f.copyWith(origins: const {})),
      if (f.codecs.isNotEmpty)
        (names(f.codecs, (c) => c.label), f.copyWith(codecs: const {})),
      if (f.hdrOnly) ('HDR only', f.copyWith(hdrOnly: false)),
      if (f.pack != PackMode.any)
        (f.pack.label, f.copyWith(pack: PackMode.any)),
      if (f.sources.isNotEmpty)
        (names(f.sources, (s) => s.label), f.copyWith(sources: const {})),
      if (f.minSeeders > 0)
        ('${f.minSeeders}+ seeders', f.copyWith(minSeeders: 0)),
      if (f.minGigabytes != null || f.maxGigabytes != null)
        (
          '${gb(f.minGigabytes)} – ${gb(f.maxGigabytes)}',
          f.copyWith(gigabytes: (null, null)),
        ),
      if (f.nameContains.trim().isNotEmpty)
        ('“${f.nameContains.trim()}”', f.copyWith(nameContains: '')),
    ];
    return Wrap(
      spacing: Space.s8,
      runSpacing: Space.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (label, without) in chips)
          SChip(label: label, removable: true, onTap: () => onChanged(without)),
        SButton.ghost(
          label: 'Clear all',
          onPressed: () => onChanged(f.cleared()),
        ),
      ],
    );
  }
}
