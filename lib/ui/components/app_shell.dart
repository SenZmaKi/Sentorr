import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/theme/theme.dart';
import '../../player/session.dart';
import '../shared/player_view.dart';
import '../shared/title_route.dart';
import 'motion.dart';
import 'navigation.dart';
import 'page_stack.dart';
import 'side_nav.dart';
import 'inert.dart';
import 'surface.dart';

enum AppDestination {
  home(Icons.home_outlined, Icons.home_rounded, 'Home'),
  search(Icons.search, Icons.search, 'Search'),
  downloads(Icons.download_outlined, Icons.download_rounded, 'Downloads'),
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
/// Pages stay alive so scroll and input persist. Title pages open over the
/// current destination, inside the same chrome.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.pages, required this.titlePage});

  final Map<AppDestination, Widget> pages;
  final Widget Function(TitleRoute route) titlePage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appDestinationProvider);
    final title = ref.watch(titleRoutesProvider).lastOrNull;
    final titles = ref.read(titleRoutesProvider.notifier);
    // Choosing a destination, even the current one, leaves any title page.
    void go(AppDestination d) {
      titles.closeAll();
      ref.read(appDestinationProvider.notifier).go(d);
    }

    final body = Stack(
      fit: StackFit.expand,
      children: [
        Inert(
          inert: title != null,
          child: FadePageStack(
            index: current.index,
            children: [
              for (final d in AppDestination.values)
                pages[d] ?? const SizedBox.shrink(),
            ],
          ),
        ),
        _TitleLayer(route: title, builder: titlePage),
      ],
    );
    // As in Senpwai: with bottom navigation, Back returns to Home before it
    // leaves the app. Rail layouts have no system Back to intercept. An open
    // title page always takes Back first.
    final bottomNav = MediaQuery.sizeOf(context).width < 600;
    // A full player sits above the shell and handles Back itself; a docked
    // one leaves Back to the app beneath it.
    final playing =
        ref.watch(playerSessionProvider.select((s) => s != null)) &&
        ref.watch(playerViewProvider) != PlayerView.mini;
    return PopScope(
      canPop:
          !playing &&
          title == null &&
          (!bottomNav || current == AppDestination.home),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || playing) return;
        if (title != null) {
          titles.back();
        } else {
          go(AppDestination.home);
        }
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

/// Fades the topmost title page in over the destination, and between
/// stacked title pages.
class _TitleLayer extends StatelessWidget {
  const _TitleLayer({required this.route, required this.builder});

  final TitleRoute? route;
  final Widget Function(TitleRoute route) builder;

  @override
  Widget build(BuildContext context) {
    final route = this.route;
    return AnimatedSwitcher(
      duration: reduceMotion(context) ? Duration.zero : Motion.reveal,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.change,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: route == null
          ? const SizedBox.shrink(key: ValueKey('no title'))
          : KeyedSubtree(key: ObjectKey(route), child: builder(route)),
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
