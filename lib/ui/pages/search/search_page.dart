import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../search/notifier.dart';
import '../../components/adaptive_sheet.dart';
import '../../components/app_shell.dart';
import '../../components/buttons.dart';
import '../../components/content_column.dart';
import '../../components/inputs.dart';
import '../../components/motion.dart';
import '../../shared/theme/theme.dart';
import 'active_filters.dart';
import 'search_filter_sheet.dart';
import 'search_filters.dart';
import 'search_results.dart';
import 'search_toolbar.dart';
import '../../shared/layout/adaptive.dart';

/// IMDb catalog search: a title field, collapsible filters summarised as
/// removable chips, ordering, and an endlessly scrolling poster grid. With
/// no term it browses the most popular movies and series.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  // How close to the end of the grid the next page starts loading.
  static const _prefetchExtent = 800.0;

  final _scroll = ScrollController();
  final _term = TextEditingController();
  final _termFocus = FocusNode();
  bool _visited = false;
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _term.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scroll.dispose();
    _term.dispose();
    _termFocus.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < _prefetchExtent) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  void _clearTerm() {
    _term.clear();
    ref.read(searchProvider.notifier).setTerm('');
    _termFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final here = ref.watch(appDestinationProvider) == AppDestination.search;
    // Start the initial search once, when this destination is first shown.
    if (!_visited && !here) return const SizedBox.shrink();
    _visited = true;
    ref.listen(appDestinationProvider, (_, next) {
      // Focusing would raise a touch keyboard over the results.
      if (next == AppDestination.search && context.input.canHover) {
        // After the page stack stops excluding this page from focus.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _termFocus.requestFocus(),
        );
      }
    });
    // A page that does not fill the viewport never scrolls to ask for more.
    ref.listen(searchProvider.select((s) => s.results), (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    });
    return LayoutBuilder(
      builder: (context, box) {
        final insets = ContentInsets(box.maxWidth);
        final gutter = insets.gutter;
        final side = insets.side;
        final layout = LayoutSize(box.biggest);
        // Phones open the filters as a sheet rather than pushing the
        // results a screen down; wider layouts expand them under the field.
        final sheetFilters = layout.compact;
        // Where height is scarce the field floats back in on any upward
        // scroll, so refining the search never means scrolling to the top.
        final floatField = layout.compact || context.screen.short;
        return Scrollbar(
          controller: _scroll,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              if (floatField)
                SliverFloatingHeader(
                  child: ColoredBox(
                    color: context.colors.surface,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        side,
                        gutter,
                        side,
                        Space.s8,
                      ),
                      child: _field(sheetFilters: sheetFilters),
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  side,
                  floatField ? Space.s8 : gutter,
                  side,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _header(
                    context,
                    sheetFilters: sheetFilters,
                    field: !floatField,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, Space.s24, side, gutter * 2),
                sliver: const SearchResults(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The search field, with the Filters button beside it.
  Widget _field({required bool sheetFilters}) {
    final filterCount = ref.watch(
      searchProvider.select((s) => s.query.filterCount),
    );
    return Row(
      children: [
        Expanded(
          child: STextField(
            controller: _term,
            focusNode: _termFocus,
            hint: 'Search movies and series',
            semanticLabel: 'Search movies and series',
            prefixIcon: Icons.search,
            textInputAction: TextInputAction.search,
            onChanged: ref.read(searchProvider.notifier).setTerm,
            trailing: _term.text.isEmpty
                ? null
                : SIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Clear search',
                    onPressed: _clearTerm,
                  ),
          ),
        ),
        const SizedBox(width: Space.s8),
        SButton(
          label: filterCount == 0 ? 'Filters' : 'Filters · $filterCount',
          icon: _filtersOpen && !sheetFilters
              ? Icons.expand_less_rounded
              : Icons.tune_rounded,
          onPressed: sheetFilters
              ? _showFilterSheet
              : () => setState(() => _filtersOpen = !_filtersOpen),
        ),
      ],
    );
  }

  void _showFilterSheet() => showAdaptiveSheet<void>(
    context,
    builder: (context) => const SearchFilterSheet(),
  );

  Widget _header(
    BuildContext context, {
    required bool sheetFilters,
    required bool field,
  }) {
    final filterCount = ref.watch(
      searchProvider.select((s) => s.query.filterCount),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (field) _field(sheetFilters: sheetFilters),
        if (!sheetFilters)
          AnimatedSize(
            duration: reduceMotion(context) ? Duration.zero : Motion.panel,
            curve: Motion.change,
            alignment: Alignment.topCenter,
            child: _filtersOpen
                ? const Padding(
                    padding: EdgeInsets.only(top: Space.s24),
                    child: SearchFilters(),
                  )
                : const SizedBox(width: double.infinity),
          ),
        if (filterCount > 0) ...[
          const SizedBox(height: Space.s16),
          const ActiveFilters(),
        ],
        const SizedBox(height: Space.s24),
        const SearchToolbar(),
      ],
    );
  }
}
