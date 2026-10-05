import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/theme/theme.dart';
import '../../player/session.dart';
import '../shared/player_view.dart';
import '../shared/title_route.dart';
import 'motion.dart';
import 'bottom_nav.dart';
import 'page_stack.dart';
import 'side_nav.dart';
import 'inert.dart';
import 'surface.dart';
import '../shared/layout/adaptive.dart';

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

/// Destinations whose page takes Back itself, e.g. settings returning from
/// an open category to the list, before the shell does.
final pageBackProvider =
    NotifierProvider<PageBackNotifier, Set<AppDestination>>(
      PageBackNotifier.new,
    );

class PageBackNotifier extends Notifier<Set<AppDestination>> {
  @override
  Set<AppDestination> build() => const {};

  void claim(AppDestination page, bool claimed) {
    if (state.contains(page) == claimed) return;
    state = claimed ? {...state, page} : ({...state}..remove(page));
  }
}

/// Responsive navigation chrome: bottom bar when compact, a slim rail above.
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
    final bottomNav = context.screen.compact;
    // Read outside the Scaffold, which hides the inset from its body.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    // A full player sits above the shell and handles Back itself; a docked
    // one leaves Back to the app beneath it.
    final playing =
        ref.watch(playerSessionProvider.select((s) => s != null)) &&
        ref.watch(playerViewProvider) != PlayerView.mini;
    final pageBack =
        title == null && ref.watch(pageBackProvider).contains(current);
    return PopScope(
      canPop:
          !playing &&
          !pageBack &&
          title == null &&
          (!bottomNav || current == AppDestination.home),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || playing || pageBack) return;
        if (title != null) {
          titles.back();
        } else {
          go(AppDestination.home);
        }
      },
      child: Scaffold(
        body: ResponsiveBuilder(
          builder: (context, layout) {
            if (layout.compact) {
              return Column(
                children: [
                  // Pages always sit on surface, as on the wider panel layout.
                  Expanded(
                    child: ColoredBox(
                      color: context.colors.surface,
                      child: SafeArea(bottom: false, child: body),
                    ),
                  ),
                  // The keyboard needs the room; the bar returns with it.
                  if (!keyboard) BottomNavBar(current: current, onSelect: go),
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
                    // A phone on its side keeps every row for the page.
                    child: layout.phoneLandscape
                        ? ColoredBox(color: context.colors.surface, child: body)
                        : Padding(
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
                                borderRadius: BorderRadius.circular(
                                  Radii.panel,
                                ),
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
