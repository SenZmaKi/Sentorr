import 'package:flutter/material.dart';

import '../../components/buttons.dart';
import '../../components/inputs.dart';
import '../../components/section_header.dart';
import '../../shared/theme/theme.dart';
import 'settings_category.dart';
import 'settings_nav.dart';
import 'settings_search.dart';

/// Settings in categories: a sidebar beside the open category on wide
/// layouts, a list that opens each category on narrow ones. Search shows
/// matching settings from every category at once.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _wide = 840.0, _content = 760.0;

  final _search = TextEditingController();
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
        final gutter = box.maxWidth < 600 ? Space.s16 : Space.s24;
        return Padding(
          padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, 0),
          child: box.maxWidth >= _wide ? _wideLayout() : _narrowLayout(),
        );
      },
    );
  }

  Widget _wideLayout() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 240,
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
      const SizedBox(width: Space.s32),
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
      child: _query.isNotEmpty
          ? Column(
              children: [
                _searchField(),
                const SizedBox(height: Space.s16),
                Expanded(child: _results()),
              ],
            )
          : opened != null
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
          : ListView(
              padding: const EdgeInsets.only(bottom: Space.s24),
              children: [
                _searchField(),
                const SizedBox(height: Space.s16),
                SettingsNav(
                  sidebar: false,
                  onSelect: (c) => setState(() => _opened = c),
                ),
              ],
            ),
    );
  }

  Widget _searchField() => STextField(
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
