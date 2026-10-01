import 'package:flutter/material.dart';

import '../components/navigation.dart';
import '../shared/theme/theme.dart';
import 'catalog_page.dart';
import 'components_page.dart';
import 'detail_page.dart';
import 'player_page.dart';
import 'sample_data.dart';
import 'settings_page.dart';

enum DemoPage { catalog, detail, player, settings, components }

class DemoShell extends StatefulWidget {
  const DemoShell({super.key, required this.themeMode, required this.onThemeMode});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;

  @override
  State<DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<DemoShell> {
  DemoPage _page = DemoPage.settings;
  SampleTitle _title = sampleTitles.first;

  static const _nav = {
    DemoPage.catalog: (Icons.grid_view_rounded, 'Discover'),
    DemoPage.detail: (Icons.movie_outlined, 'Title detail'),
    DemoPage.player: (Icons.play_circle_outline, 'Player'),
    DemoPage.settings: (Icons.tune, 'Settings'),
    DemoPage.components: (Icons.widgets_outlined, 'Components'),
  };

  void _go(DemoPage p) => setState(() => _page = p);

  Widget _content() => switch (_page) {
    DemoPage.catalog => CatalogPage(
      onOpen: (t) => setState(() {
        _title = t;
        _page = DemoPage.detail;
      }),
    ),
    DemoPage.detail => DetailPage(title: _title, onPlay: () => _go(DemoPage.player)),
    DemoPage.player => PlayerPage(title: _title),
    DemoPage.settings => const SettingsPage(),
    DemoPage.components => const ComponentsPage(),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final full = width >= 960;
          final compact = width < 600;
          final gutter = compact ? Space.s16 : Space.s24;
          final page = SingleChildScrollView(
            padding: EdgeInsets.all(gutter),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: AnimatedSwitcher(
                  layoutBuilder: (current, previous) =>
                      Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),

                  duration: Motion.panel,
                  child: KeyedSubtree(key: ValueKey(_page), child: _content()),
                ),
              ),
            ),
          );
          if (compact) {
            return Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(Space.s8),
                    child: Row(children: [for (final e in _nav.entries) _navItem(e.key, e.value, compact: true)]),
                  ),
                ),
                Divider(color: c.borderSubtle),
                Expanded(child: page),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: full ? 248 : 72,
                child: Padding(
                  padding: const EdgeInsets.all(Space.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Space.s12, Space.s12, Space.s12, Space.s24),
                        child: Row(
                          children: [
                            Icon(Icons.stream, color: c.foreground, size: IconSizes.navigation),
                            if (full) ...[
                              const SizedBox(width: Space.s8),
                              Text('Sentorr', style: context.type.subtitle.copyWith(color: c.foreground)),
                            ],
                          ],
                        ),
                      ),
                      for (final e in _nav.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.s4),
                          child: _navItem(e.key, e.value, compact: !full),
                        ),
                      const Spacer(),
                      if (full)
                        SegmentedTabs(
                          value: widget.themeMode,
                          segments: const {
                            ThemeMode.light: 'Light',
                            ThemeMode.dark: 'Dark',
                            ThemeMode.system: 'System',
                          },
                          onChanged: widget.onThemeMode,
                        )
                      else
                        _navItem(null, (Icons.contrast, 'Toggle theme'), compact: true),
                    ],
                  ),
                ),
              ),
              Expanded(child: page),
            ],
          );
        },
      ),
    );
  }

  Widget _navItem(DemoPage? p, (IconData, String) item, {required bool compact}) => NavItem(
    icon: item.$1,
    label: item.$2,
    compact: compact,
    selected: p == _page,
    onTap: p != null
        ? () => _go(p)
        : () => widget.onThemeMode(Theme.of(context).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark),
  );
}
