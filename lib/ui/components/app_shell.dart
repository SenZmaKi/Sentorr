import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/theme/theme.dart';
import 'navigation.dart';
import 'page_stack.dart';
import 'side_nav.dart';
import 'surface.dart';

enum AppDestination {
  home(Icons.home_outlined, Icons.home_rounded, 'Home'),
  search(Icons.search, Icons.search, 'Search'),
  settings(Icons.settings_outlined, Icons.settings_rounded, 'Settings');

  const AppDestination(this.icon, this.selectedIcon, this.label);
  final IconData icon, selectedIcon;
  final String label;
}

/// The active top-level page; pages may switch it, e.g. a home call to search.
final appDestinationProvider =
    NotifierProvider<AppDestinationNotifier, AppDestination>(
      AppDestinationNotifier.new,
    );

class AppDestinationNotifier extends Notifier<AppDestination> {
  @override
  AppDestination build() => AppDestination.home;

  void go(AppDestination destination) => state = destination;
}

/// Responsive navigation chrome: bottom bar below 600, a slim rail above.
/// Pages stay alive so scroll and input persist.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.pages});

  final Map<AppDestination, Widget> pages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appDestinationProvider);
    void go(AppDestination d) =>
        ref.read(appDestinationProvider.notifier).go(d);
    final body = FadePageStack(
      index: current.index,
      children: [
        for (final d in AppDestination.values)
          pages[d] ?? const SizedBox.shrink(),
      ],
    );
    // As in Senpwai: with bottom navigation, Back returns to Home before it
    // leaves the app. Rail layouts have no system Back to intercept.
    final bottomNav = MediaQuery.sizeOf(context).width < 600;
    return PopScope(
      canPop: !bottomNav || current == AppDestination.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) go(AppDestination.home);
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth < 600) {
              return Column(
                children: [
                  // Pages always sit on surface, as on the wider panel layout.
                  Expanded(
                    child: ColoredBox(
                      color: context.colors.surface,
                      child: SafeArea(bottom: false, child: body),
                    ),
                  ),
                  _BottomBar(current: current, onSelect: go),
                ],
              );
            }
            return SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SideNav(current: current, onSelect: go),
                  // Pages sit on a panel above the canvas the nav shares.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        0,
                        Space.s8,
                        Space.s8,
                        Space.s8,
                      ),
                      child: DepthBox(
                        style: context.depth.of(SurfaceDepth.panel),
                        radius: Radii.panel,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.panel),
                          child: body,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.current, required this.onSelect});

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s8,
            vertical: Space.s4,
          ),
          child: Row(
            children: [
              for (final d in AppDestination.values)
                Expanded(
                  child: BottomNavItem(
                    icon: d == current ? d.selectedIcon : d.icon,
                    label: d.label,
                    selected: d == current,
                    onTap: () => onSelect(d),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
