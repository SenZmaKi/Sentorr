import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../search/models.dart';
import '../../../search/notifier.dart';
import '../../components/select.dart';
import '../../shared/theme/theme.dart';
import 'range_field.dart';

Set<T> toggled<T>(Set<T> set, T value) =>
    set.contains(value) ? ({...set}..remove(value)) : {...set, value};

T? Function(String) _clamped<T extends num>(
  T? Function(String) parse,
  T low,
  T high,
) => (text) {
  final v = parse(text.trim());
  return v == null ? null : v.clamp(low, high) as T;
};

/// Genre, type, rating, year and runtime controls in an even grid whose
/// column count follows the available width.
class SearchFilters extends ConsumerWidget {
  const SearchFilters({super.key});

  // Narrow enough for two range inputs and their "to".
  static const _minColumnWidth = 200.0;

  // Wide enough that neighbouring filters read as separate groups.
  static const _columnGap = Space.s32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(searchProvider.select((s) => s.query));
    final search = ref.read(searchProvider.notifier);
    final fields = [
      _Labeled(
        label: 'Genre',
        icon: Icons.theater_comedy_outlined,
        child: SSelect<String>(
          options: imdbGenres,
          selected: q.genres,
          labelOf: (g) => g,
          multiple: true,
          semanticLabel: 'Genre',
          onSelected: (g) =>
              search.update((q) => q.copyWith(genres: toggled(q.genres, g))),
          onClear: () => search.update((q) => q.copyWith(genres: const {})),
        ),
      ),
      _Labeled(
        label: 'Type',
        icon: Icons.movie_outlined,
        child: SSelect<TitleKind>(
          options: TitleKind.values,
          selected: q.kinds,
          labelOf: (k) => k.label,
          multiple: true,
          semanticLabel: 'Type',
          placeholder: 'Movies and series',
          onSelected: (k) =>
              search.update((q) => q.copyWith(kinds: toggled(q.kinds, k))),
          onClear: () => search.update((q) => q.copyWith(kinds: const {})),
        ),
      ),
      _Labeled(
        label: 'Rating',
        icon: Icons.star_outline_rounded,
        child: RangeField<double>(
          name: 'rating',
          decimal: true,
          value: q.rating,
          parse: _clamped(double.tryParse, 0.0, 10.0),
          onChanged: (b) => search.update((q) => q.copyWith(rating: b)),
        ),
      ),
      _Labeled(
        label: 'Year',
        icon: Icons.calendar_today_outlined,
        child: RangeField<int>(
          name: 'year',
          value: q.years,
          parse: _clamped(int.tryParse, 1870, DateTime.now().year + 10),
          onChanged: (b) => search.update((q) => q.copyWith(years: b)),
        ),
      ),
      _Labeled(
        label: 'Runtime (min)',
        icon: Icons.schedule_rounded,
        child: RangeField<int>(
          name: 'runtime in minutes',
          value: q.runtime,
          parse: _clamped(int.tryParse, 0, 9999),
          onChanged: (b) => search.update((q) => q.copyWith(runtime: b)),
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final columns =
            ((box.maxWidth + _columnGap) / (_minColumnWidth + _columnGap))
                .floor()
                .clamp(1, fields.length);
        return Column(
          spacing: Space.s24,
          children: [
            for (var i = 0; i < fields.length; i += columns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: _columnGap,
                children: [
                  for (var j = i; j < i + columns; j++)
                    Expanded(
                      child: j < fields.length ? fields[j] : const SizedBox(),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({
    required this.label,
    required this.icon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              Icon(icon, size: IconSizes.metadata, color: c.foregroundMuted),
              const SizedBox(width: Space.s8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.label.copyWith(
                    color: c.foregroundSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.s8),
        child,
      ],
    );
  }
}
