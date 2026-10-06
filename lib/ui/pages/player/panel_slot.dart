import 'package:flutter/material.dart';

import '../../components/motion.dart';
import '../../shared/theme/theme.dart';
import 'player_dock.dart';
import 'player_layout.dart';

/// One open player panel, with the width it would like.
typedef SlotPanel = ({Widget child, double width});

/// Where the open panel sits, by [PanelPlacement]: a card floating above
/// the bar's trailing end, a full-height side sheet on a phone held
/// sideways, or a full-width bottom sheet on one held upright. Wide
/// players dock it beside the picture through [PlayerDock] instead. Panels get
/// a bounded height and scroll within it; switching panels crossfades.
class PanelSlot extends StatelessWidget {
  const PanelSlot({
    super.key,
    required this.panel,
    required this.floatingBars,
    this.popup = false,
  });

  /// Null when no panel is open.
  final SlotPanel? panel;
  final bool floatingBars;
  final bool popup;

  @override
  Widget build(BuildContext context) {
    final layout = context.playerLayout;
    final duration = reduceMotion(context) ? Duration.zero : Motion.panel;
    final placement = popup ? PanelPlacement.floating : layout.panels;
    final alignment = switch (placement) {
      PanelPlacement.bottomSheet => Alignment.bottomCenter,
      PanelPlacement.sideSheet ||
      PanelPlacement.docked => Alignment.centerRight,
      PanelPlacement.floating => Alignment.bottomRight,
    };
    final panel = this.panel;
    final content = LayoutBuilder(
      builder: (context, box) => AnimatedSwitcher(
        duration: duration,
        switchInCurve: Motion.enter,
        switchOutCurve: Motion.change,
        layoutBuilder: (current, previous) =>
            Stack(alignment: alignment, children: [...previous, ?current]),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: placement == PanelPlacement.sideSheet
                  ? const Offset(0.02, 0)
                  : const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: panel == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : KeyedSubtree(
                key: panel.child.key,
                child: SizedBox(
                  width: layout.panelWidth(panel.width, box.maxWidth),
                  child: panel.child,
                ),
              ),
      ),
    );
    final height = MediaQuery.sizeOf(context).height;
    // The player sits above the app's Scaffold, so it lifts panels over the
    // keyboard itself (the torrents panel has a search field).
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return switch (placement) {
      // [PlayerDock] places it beside the picture instead.
      PanelPlacement.docked => const SizedBox.shrink(),
      PanelPlacement.floating => Positioned(
        left: Space.s16,
        right: Space.s16,
        bottom: keyboard + layout.barClearance(floatingBars: floatingBars),
        top: layout.topClearance(floatingBars: floatingBars),
        child: SafeArea(child: content),
      ),
      PanelPlacement.sideSheet => Positioned.fill(
        bottom: keyboard,
        child: SafeArea(
          minimum: const EdgeInsets.all(Space.s8),
          child: content,
        ),
      ),
      PanelPlacement.bottomSheet => Positioned(
        left: 0,
        right: 0,
        bottom: keyboard,
        // The top quarter stays picture, to tap away the sheet.
        top: keyboard > 0 ? 0 : height / 4,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.all(Space.s8),
          child: content,
        ),
      ),
    };
  }
}
