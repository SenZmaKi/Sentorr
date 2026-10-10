import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'app_shell.dart';
import 'motion.dart';
import 'navigation.dart';
import 'surface.dart';
import 'update_navigation_action.dart';

/// Slim rail on the canvas: the app mark, then one icon-over-label target
/// per destination. A single raised pill glides to the current page.
class SideNav extends StatelessWidget {
  const SideNav({super.key, required this.current, required this.onSelect});

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;

  static const double width = 80;
  static const _gap = Space.s8;

  @override
  Widget build(BuildContext context) {
    const item = RailNavItem.size;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          const SizedBox(height: Space.s16),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.control),
            child: Image.asset(
              context.brand.logo,
              width: 32,
              cacheWidth: (32 * MediaQuery.devicePixelRatioOf(context)).ceil(),
              height: 32,
              semanticLabel: 'Sentorr',
            ),
          ),
          const SizedBox(height: Space.s24),
          // A phone on its side is shorter than the rail: scroll, never
          // overflow.
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                width: item,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: reduceMotion(context)
                          ? Duration.zero
                          : Motion.reveal,
                      curve: Motion.change,
                      top: current.index * (item + _gap),
                      left: 0,
                      width: item,
                      height: item,
                      child: DepthBox(
                        style: context.depth.of(SurfaceDepth.raised),
                        radius: Radii.card,
                      ),
                    ),
                    Column(
                      children: [
                        for (final d in AppDestination.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: _gap),
                            child: RailNavItem(
                              icon: d == current ? d.selectedIcon : d.icon,
                              label: d.label,
                              selected: d == current,
                              onTap: () => onSelect(d),
                            ),
                          ),
                        const UpdateNavigationAction(rail: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
