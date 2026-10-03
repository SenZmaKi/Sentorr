import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/theme/theme.dart';
import 'app_shell.dart';
import 'navigation.dart';

/// Height the bottom navigation takes from the window's bottom edge, its
/// safe-area inset included; 0 while it is not shown. Overlays above the
/// shell, such as the docked player, clear it by this much.
final bottomNavExtentProvider = NotifierProvider<_NavExtent, double>(
  _NavExtent.new,
);

class _NavExtent extends Notifier<double> {
  @override
  double build() => 0;

  void set(double extent) {
    // Reported after a frame, possibly once the app has been torn down.
    if (ref.mounted && extent != state) state = extent;
  }
}

/// Compact navigation along the bottom edge, padded clear of the gesture
/// bar. Reports its measured height to [bottomNavExtentProvider].
class BottomNavBar extends ConsumerStatefulWidget {
  const BottomNavBar({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;

  @override
  ConsumerState<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends ConsumerState<BottomNavBar> {
  late final _extent = ref.read(bottomNavExtentProvider.notifier);
  static int _mounted = 0;

  @override
  void initState() {
    super.initState();
    _mounted++;
  }

  void _report() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _extent.set(context.size?.height ?? 0);
  });

  @override
  void dispose() {
    // After this frame: providers must not change while the tree builds.
    final extent = _extent;
    _mounted--;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted == 0) extent.set(0);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-measured whenever the inset or text size it depends on changes.
    MediaQuery.paddingOf(context);
    MediaQuery.textScalerOf(context);
    _report();
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
                    icon: d == widget.current ? d.selectedIcon : d.icon,
                    label: d.label,
                    selected: d == widget.current,
                    onTap: () => widget.onSelect(d),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
