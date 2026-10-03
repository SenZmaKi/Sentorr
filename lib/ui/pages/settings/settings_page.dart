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
/// matching settings from every category at once.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// Settings rows hold a label column and a control; past this the pair
  /// drifts apart, so the open category caps here.
  static const _content = 760.0;

  final _search = TextEditingController();

  /// Keeps the field's state, and so its focus, wherever layouts place it.
  final _searchKey = GlobalKey();
  SettingsCategory _category = SettingsCategory.playback;

  /// The category opened on a narrow layout; null shows the list.
  SettingsCategory? _opened;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String value) => setState(() => _query = value.trim());

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
        constraints: BoxConstraints(maxWidth: sidebar + gap + _content),
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
    final c = context.colors;
    final matches = [
      for (final category in SettingsCategory.available)
        if (settingsMatch(_query, [category.title, category.keywords]))
          category,
    ];
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.s24),
        child: Text(
          'No settings match “$_query”.',
          style: context.type.body.copyWith(color: c.foregroundSecondary),
        ),
      );
    }
    return _scroll([
      for (final category in matches) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s12),
          child: Text(
            category.title,
            style: context.type.subtitle.copyWith(color: c.foreground),
          ),
        ),
        // A category found by its own name shows everything in it.
        SettingsQuery(
          query: settingsMatch(_query, [category.title]) ? null : _query,
          child: category.content,
        ),
      ],
    ]);
  }

  Widget _scroll(List<Widget> children) => SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: Space.s24),
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
