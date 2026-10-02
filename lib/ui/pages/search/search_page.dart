import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../search/notifier.dart';
import '../../components/app_shell.dart';
import '../../components/buttons.dart';
import '../../components/inputs.dart';
import '../../components/interactive.dart';
import '../../components/motion.dart';
import '../../shared/theme/theme.dart';
import 'active_filters.dart';
import 'search_filters.dart';
import 'search_results.dart';
import 'search_toolbar.dart';

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
    // The page is built hidden at launch; search IMDb only once it is seen.
    if (!_visited && !here) return const SizedBox.shrink();
    _visited = true;
    ref.listen(appDestinationProvider, (_, next) {
      if (next == AppDestination.search &&
          MediaQuery.sizeOf(context).width >= 600) {
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
        final gutter = box.maxWidth < 600 ? Space.s16 : Space.s24;
        // Centres content at the shared 1400 cap while the scrollbar stays
        // at the window edge.
        final side = ((box.maxWidth - 1400) / 2).clamp(gutter, double.infinity);
        return Scrollbar(
          controller: _scroll,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, gutter, side, 0),
                sliver: SliverToBoxAdapter(child: _header(context)),
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

  Widget _header(BuildContext context) {
    final c = context.colors;
    final filterCount = ref.watch(
      searchProvider.select((s) => s.query.filterCount),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
                    : Interactive(
                        onTap: _clearTerm,
                        semanticLabel: 'Clear search',
                        borderRadius: Radii.full,
                        builder: (context, s) => Icon(
                          Icons.close_rounded,
                          size: IconSizes.metadata,
                          color: s.hovered ? c.foreground : c.foregroundMuted,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: Space.s8),
            SButton(
              label: filterCount == 0 ? 'Filters' : 'Filters · $filterCount',
              icon: _filtersOpen
                  ? Icons.expand_less_rounded
                  : Icons.tune_rounded,
              onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
            ),
          ],
        ),
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
