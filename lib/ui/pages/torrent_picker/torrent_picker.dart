import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../torrents/providers.dart';
import '../../../torrents/resolution_models.dart';
import '../../components/buttons.dart';
import '../../components/inputs.dart';
import '../../shared/theme/theme.dart';
import 'picker_filters.dart';
import 'picker_toolbar.dart';
import 'torrent_option.dart';

/// Every torrent found for one item, to sort, narrow and choose from.
/// Filters are shared across pickers for the session. Tapping a row only
/// selects it; the host owns the action that uses the choice.
class TorrentPicker extends ConsumerStatefulWidget {
  const TorrentPicker({
    super.key,
    required this.candidates,
    required this.selected,
    required this.onSelected,
    this.playing,
    this.failed = const {},
    this.title,
    this.onSearch,
  });

  /// Best first, as the resolver ranked them.
  final List<TorrentCandidate> candidates;
  final TorrentCandidate? selected;
  final ValueChanged<TorrentCandidate> onSelected;

  /// Info hash of the torrent streaming now, and of those that failed.
  final String? playing;
  final Set<String> failed;

  /// With [onSearch], a field to search again under another title.
  final TextEditingController? title;
  final ValueChanged<String>? onSearch;

  @override
  ConsumerState<TorrentPicker> createState() => _TorrentPickerState();
}

class _TorrentPickerState extends ConsumerState<TorrentPicker> {
  bool _filtersOpen = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filters = ref.watch(torrentFiltersProvider);
    final setFilters = ref.read(torrentFiltersProvider.notifier).set;
    final all = widget.candidates;
    final shown = filters.apply(all);
    final best = all.firstOrNull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onSearch case final search?) ...[
          STextField(
            controller: widget.title,
            prefixIcon: Icons.search,
            hint: 'Search under another title',
            semanticLabel: 'Title to search for',
            textInputAction: TextInputAction.search,
            onSubmitted: search,
          ),
          const SizedBox(height: Space.s12),
        ],
        PickerToolbar(
          filters: filters,
          filtersOpen: _filtersOpen,
          onToggleFilters: () => setState(() => _filtersOpen = !_filtersOpen),
          onChanged: setFilters,
        ),
        const SizedBox(height: Space.s12),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              if (_filtersOpen) ...[
                PickerFilters(
                  filters: filters,
                  candidates: all,
                  onChanged: setFilters,
                ),
                const SizedBox(height: Space.s16),
                const Divider(height: 1),
                const SizedBox(height: Space.s12),
              ] else if (filters.activeCount > 0) ...[
                ActiveFilterChips(filters: filters, onChanged: setFilters),
                const SizedBox(height: Space.s8),
              ],
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s8),
                child: Text(
                  shown.length == all.length
                      ? '${all.length} ${all.length == 1 ? 'torrent' : 'torrents'}'
                      : '${shown.length} of ${all.length} torrents',
                  style: context.type.bodySmall.copyWith(
                    color: c.foregroundMuted,
                  ),
                ),
              ),
              if (shown.isEmpty)
                _NoneShown(onClear: () => setFilters(filters.cleared()))
              else
                for (final (i, candidate) in shown.indexed) ...[
                  if (i > 0) Divider(height: 1, color: c.borderSubtle),
                  TorrentOption(
                    candidate: candidate,
                    best: identical(candidate, best),
                    selected: identical(candidate, widget.selected),
                    mark: _mark(candidate),
                    onTap: () => widget.onSelected(candidate),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  OptionMark _mark(TorrentCandidate candidate) {
    final hash = candidate.release.infoHash;
    if (hash == widget.playing) return OptionMark.playing;
    if (widget.failed.contains(hash)) return OptionMark.failed;
    return OptionMark.none;
  }
}

class _NoneShown extends StatelessWidget {
  const _NoneShown({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.s16),
    child: Column(
      spacing: Space.s12,
      children: [
        Text(
          'No torrent matches these filters.',
          textAlign: TextAlign.center,
          style: context.type.bodySmall.copyWith(
            color: context.colors.foregroundSecondary,
          ),
        ),
        SButton(
          label: 'Clear filters',
          icon: Icons.filter_alt_off_outlined,
          onPressed: onClear,
        ),
      ],
    ),
  );
}
