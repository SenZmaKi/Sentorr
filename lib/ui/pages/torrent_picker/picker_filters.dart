import 'package:flutter/material.dart';

import '../../../search/models.dart';
import '../../../torrents/filters.dart';
import '../../../torrents/models.dart';
import '../../../torrents/release_traits.dart';
import '../../../torrents/resolution_models.dart';
import '../../components/inputs.dart';
import '../../components/range_field.dart';
import '../../components/select.dart';
import '../../shared/theme/theme.dart';

Set<T> _toggled<T>(Set<T> set, T value) =>
    set.contains(value) ? ({...set}..remove(value)) : {...set, value};

/// Every way to narrow the torrents, as a dense grid of dropdowns whose
/// column count follows the width, then size and name inputs on one row.
/// A dropdown only offers values some torrent has, each menu entry with how
/// many have it, and hides when there is nothing to choose between.
class PickerFilters extends StatefulWidget {
  const PickerFilters({
    super.key,
    required this.filters,
    required this.candidates,
    required this.onChanged,
  });

  final TorrentFilters filters;

  /// Everything found, before filtering.
  final List<TorrentCandidate> candidates;
  final ValueChanged<TorrentFilters> onChanged;

  @override
  State<PickerFilters> createState() => _PickerFiltersState();
}

class _PickerFiltersState extends State<PickerFilters> {
  // Room for an icon and a short value such as "1080p, 4K".
  static const _minColumnWidth = 150.0;

  // Below this, size and name each take the full width.
  static const _inputsSideBySide = 440.0;

  late final _name = TextEditingController(text: widget.filters.nameContains);

  @override
  void didUpdateWidget(PickerFilters old) {
    super.didUpdateWidget(old);
    // Cleared elsewhere, e.g. by the summary's Clear all.
    if (widget.filters.nameContains != _name.text) {
      _name.text = widget.filters.nameContains;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filters;
    final all = widget.candidates;
    final traits = [for (final c in all) ReleaseTraits.of(c.release.name)];
    final set = widget.onChanged;

    Widget? many<T>({
      required String name,
      required IconData icon,
      required List<T> values,
      required Iterable<T?> present,
      required Set<T> selected,
      required String Function(T) labelOf,
      required ValueChanged<Set<T>> onChanged,
    }) {
      final counts = <T, int>{};
      for (final v in present.whereType<T>()) {
        counts.update(v, (n) => n + 1, ifAbsent: () => 1);
      }
      final shown = [
        for (final v in values)
          if (counts.containsKey(v) || selected.contains(v)) v,
      ];
      if (shown.length < 2 && selected.isEmpty) return null;
      return SSelect<T>(
        options: shown,
        selected: selected,
        labelOf: labelOf,
        optionLabelOf: (v) => '${labelOf(v)} · ${counts[v] ?? 0}',
        multiple: true,
        icon: icon,
        placeholder: 'Any ${name.toLowerCase()}',
        semanticLabel: name,
        onSelected: (v) => onChanged(_toggled(selected, v)),
        onClear: () => onChanged(const {}),
      );
    }

    final hdr = traits.where((t) => t.hdr).length;
    final hasPacks = all.any((c) => c.requiresFileSelection);
    final hasEpisodes = all.any((c) => !c.requiresFileSelection);
    final fields = <Widget?>[
      many<QualityBand>(
        name: 'Quality',
        icon: Icons.high_quality_outlined,
        values: QualityBand.values,
        present: all.map((c) => QualityBand.of(c.release.resolution)),
        selected: f.qualities,
        labelOf: (q) => q.label,
        onChanged: (v) => set(f.copyWith(qualities: v)),
      ),
      many<VideoOrigin>(
        name: 'Source',
        icon: Icons.album_outlined,
        values: VideoOrigin.values,
        present: traits.map((t) => t.origin),
        selected: f.origins,
        labelOf: (o) => o.label,
        onChanged: (v) => set(f.copyWith(origins: v)),
      ),
      many<VideoCodec>(
        name: 'Codec',
        icon: Icons.memory_rounded,
        values: VideoCodec.values,
        present: traits.map((t) => t.codec),
        selected: f.codecs,
        labelOf: (c) => c.label,
        onChanged: (v) => set(f.copyWith(codecs: v)),
      ),
      if (hdr > 0 || f.hdrOnly)
        SSelect<bool>(
          options: const [true],
          selected: {if (f.hdrOnly) true},
          labelOf: (_) => 'HDR only',
          optionLabelOf: (_) => 'HDR only · $hdr',
          icon: Icons.hdr_on_outlined,
          placeholder: 'Any range',
          semanticLabel: 'Dynamic range',
          onSelected: (_) => set(f.copyWith(hdrOnly: true)),
          onClear: () => set(f.copyWith(hdrOnly: false)),
        ),
      if ((hasPacks && hasEpisodes) || f.pack != PackMode.any)
        SSelect<PackMode>(
          options: const [PackMode.episode, PackMode.season, PackMode.series],
          selected: {if (f.pack != PackMode.any) f.pack},
          labelOf: (m) => m.label,
          icon: Icons.layers_outlined,
          placeholder: 'Episodes and packs',
          semanticLabel: 'Contents',
          onSelected: (m) => set(f.copyWith(pack: m)),
          onClear: () => set(f.copyWith(pack: PackMode.any)),
        ),
      many<TorrentSourceId>(
        name: 'Site',
        icon: Icons.travel_explore,
        values: TorrentSourceId.values,
        present: all.map((c) => c.release.source),
        selected: f.sources,
        labelOf: (s) => s.label,
        onChanged: (v) => set(f.copyWith(sources: v)),
      ),
      SSelect<int>(
        options: TorrentFilters.seederSteps.skip(1).toList(),
        selected: {if (f.minSeeders > 0) f.minSeeders},
        labelOf: (n) => '$n+ seeders',
        icon: Icons.group_outlined,
        placeholder: 'Any seeders',
        semanticLabel: 'Minimum seeders',
        onSelected: (n) => set(f.copyWith(minSeeders: n)),
        onClear: () => set(f.copyWith(minSeeders: 0)),
      ),
    ].nonNulls.toList();

    final size = Row(
      spacing: Space.s8,
      children: [
        Icon(
          Icons.save_outlined,
          size: IconSizes.metadata,
          color: context.colors.foregroundMuted,
        ),
        Text(
          'GB',
          style: context.type.label.copyWith(
            color: context.colors.foregroundSecondary,
          ),
        ),
        Expanded(
          child: RangeField<double>(
            name: 'size in gigabytes',
            decimal: true,
            value: Bounds(min: f.minGigabytes, max: f.maxGigabytes),
            parse: (text) {
              final v = double.tryParse(text.trim());
              return v == null || v < 0 ? null : v;
            },
            onChanged: (b) => set(f.copyWith(gigabytes: (b.min, b.max))),
          ),
        ),
      ],
    );
    final name = STextField(
      controller: _name,
      technical: true,
      prefixIcon: Icons.text_fields_rounded,
      hint: 'Name contains',
      semanticLabel: 'Torrent name contains',
      onChanged: (text) => set(f.copyWith(nameContains: text)),
    );

    return LayoutBuilder(
      builder: (context, box) {
        const gap = Space.s12;
        final columns = ((box.maxWidth + gap) / (_minColumnWidth + gap))
            .floor()
            .clamp(1, fields.length);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: [
            for (var i = 0; i < fields.length; i += columns)
              Row(
                spacing: gap,
                children: [
                  for (var j = i; j < i + columns; j++)
                    Expanded(
                      child: j < fields.length ? fields[j] : const SizedBox(),
                    ),
                ],
              ),
            if (box.maxWidth < _inputsSideBySide) ...[
              size,
              name,
            ] else
              Row(
                spacing: gap,
                children: [
                  Expanded(child: size),
                  Expanded(child: name),
                ],
              ),
          ],
        );
      },
    );
  }
}
