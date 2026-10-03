import 'package:flutter/material.dart';

import '../../components/motion.dart';
import '../../shared/theme/theme.dart';
import 'panel_slot.dart';
import 'player_layout.dart';

/// On wide players ([PanelPlacement.docked]) the open panel sits in a
/// column beside the picture, which shrinks to make room rather than being
/// covered. Elsewhere it passes [child] through and [PanelSlot] places the
/// panel over the picture.
class PlayerDock extends StatelessWidget {
  const PlayerDock({super.key, required this.panel, required this.child});

  /// The open panel; null when none is.
  final SlotPanel? panel;

  /// The picture and everything drawn over it.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final layout = context.playerLayout;
    final docked = layout.panels == PanelPlacement.docked ? panel : null;
    final duration = reduceMotion(context) ? Duration.zero : Motion.panel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: child),
        ClipRect(
          child: AnimatedSize(
            duration: duration,
            curve: Motion.change,
            alignment: Alignment.centerLeft,
            child: docked == null
                ? const SizedBox(width: 0)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      Space.s16,
                      Space.s16,
                      Space.s16,
                    ),
                    child: SafeArea(
                      left: false,
                      child: Align(
                        alignment: Alignment.topCenter,
                        // At most half the player, so the picture keeps
                        // the larger share.
                        child: SizedBox(
                          width: layout.panelWidth(
                            docked.width,
                            layout.size.size.width / 2,
                          ),
                          child: docked.child,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
