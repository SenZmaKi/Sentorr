import 'package:flutter/material.dart';

import '../../components/buttons.dart';
import '../../components/inputs.dart';
import '../../components/section_header.dart';
import '../../shared/theme/theme.dart';
import 'settings_category.dart';
import 'settings_nav.dart';
import 'settings_search.dart';
import '../../shared/layout/adaptive.dart';

/// Settings in categories: a sidebar beside the open category from medium
/// (narrower there), a list that opens each category on compact. Search shows
/// matching settings from every category at once, each group naming its
/// category; typos are forgiven only when nothing matches as typed.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// Settings rows hold a label column and a control; past this the pair
  /// drifts apart, so the open category caps here.
  static const _content = 760.0;

  /// Room between the content and a pointer's scrollbar.
  static const _scrollbarGap = Space.s32;

  final _search = TextEditingController();

  /// Keeps the field's state, and so its focus, wherever layouts place it.
  final _searchKey = GlobalKey();
  SettingsCategory _category = SettingsCategory.torrents;

  /// The category opened on a narrow layout; null shows the list.
  SettingsCategory? _opened;
  String _query = '';

  /// Whether the search is retried forgiving typos, after finding nothing.
  bool _fuzzy = false;

  /// Whether neither try found anything; until then results may still be
  /// settling, so no message shows.
  bool _nothing = false;
  SettingsHits? _hits;

  @override
  void dispose() {
    _hits?.close();
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    final query = value.trim();
    if (query == _query) return;
    setState(() {
      _query = query;
      _fuzzy = false;
      _nothing = false;
      _renewHits();
    });
  }

  void _renewHits() {
    _hits?.close();
    _hits = _query.isEmpty ? null : SettingsHits(_onSettled);
  }

  void _onSettled(bool found) {
    if (!mounted) return;
    if (found) {
      if (_nothing) setState(() => _nothing = false);
    } else if (!_fuzzy) {
      setState(() {
        _fuzzy = true;
        _renewHits();
      });
    } else if (!_nothing) {
      setState(() => _nothing = true);
    }
  }

  void _openFromResults(SettingsCategory category) {
    _clearQuery();
    setState(() {
      _category = category;
      _opened = category;
    });
  }

  void _clearQuery() {
    _search.clear();
    _setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final layout = LayoutSize(box.biggest);
        final gutter = gutterFor(layout);
        return Padding(
          padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, 0),
          child: layout.compact ? _narrowLayout() : _wideLayout(layout),
        );
      },
    );
  }

  /// Sidebar, gap and the content's reading cap: on expanded and large
  /// windows the pair centres instead of hugging the left edge. Medium
  /// narrows the sidebar and gap so the content keeps its room.
  Widget _wideLayout(LayoutSize layout) {
    final sidebar = layout.pick(compact: 200.0, expanded: 240.0);
    final gap = layout.pick(compact: Space.s24, expanded: Space.s32);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: sidebar + gap + _content + _scrollbarGap,
        ),
        child: _sidebarLayout(sidebar, gap),
      ),
    );
  }

  Widget _sidebarLayout(double sidebar, double gap) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: sidebar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _searchField(),
            const SizedBox(height: Space.s16),
            Expanded(
              child: SingleChildScrollView(
                child: SettingsNav(
                  active: _query.isEmpty ? _category : null,
                  onSelect: (c) {
                    _clearQuery();
                    setState(() => _category = c);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      SizedBox(width: gap),
      Expanded(child: _query.isNotEmpty ? _results() : _page(_category)),
    ],
  );

  Widget _narrowLayout() {
    final opened = _opened;
    return PopScope(
      canPop: opened == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _opened = null);
      },
      // The search field keeps one place in one structure whether the
      // list or the results show, so typing never rebuilds it and drops
      // focus (and the keyboard) after the first character.
      child: opened != null && _query.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SButton.ghost(
                  label: 'All settings',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => setState(() => _opened = null),
                ),
                const SizedBox(height: Space.s8),
                Expanded(child: _page(opened)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _searchField(),
                const SizedBox(height: Space.s16),
                Expanded(
                  child: _query.isNotEmpty
                      ? _results()
                      : ListView(
                          padding: const EdgeInsets.only(bottom: Space.s24),
                          children: [
                            SettingsNav(
                              sidebar: false,
                              onSelect: (c) => setState(() => _opened = c),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _searchField() => STextField(
    key: _searchKey,
    controller: _search,
    hint: 'Search settings',
    semanticLabel: 'Search settings',
    prefixIcon: Icons.search_rounded,
    onChanged: _setQuery,
    trailing: _query.isEmpty
        ? null
        : SIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Clear search',
            onPressed: _clearQuery,
          ),
  );

  Widget _page(SettingsCategory category) => _scroll([
    SectionHeader(
      icon: category.icon,
      title: category.title,
      subtitle: category.subtitle,
    ),
    const SizedBox(height: Space.s24),
    category.content,
  ]);

  Widget _results() {
    final search = SettingsSearch(_query, fuzzy: _fuzzy);
    return _scroll([
      if (_nothing)
        Padding(
          padding: const EdgeInsets.only(top: Space.s24),
          child: Text(
            'No settings match “$_query”.',
            style: context.type.body.copyWith(
              color: context.colors.foregroundSecondary,
            ),
          ),
        ),
      for (final category in SettingsCategory.available)
        SettingsQuery(
          // A category found by its own name shows everything in it.
          search: search.matches([category.title]) ? null : search,
          hits: _hits,
          category: category.title,
          onOpenCategory: () => _openFromResults(category),
          child: category.content,
        ),
    ]);
  }

  // Keeps the content clear of a pointer's scrollbar, which stays over the
  // view's edge; touch scrollbars only show while scrolling.
  Widget _scroll(List<Widget> children) => SingleChildScrollView(
    padding: EdgeInsets.only(
      right: context.input.canHover ? _scrollbarGap : 0,
      bottom: Space.s24,
    ),
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _content),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}
