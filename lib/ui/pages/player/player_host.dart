import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../player/session.dart';
import '../../components/bottom_nav.dart';
import '../../components/inert.dart';
import '../../components/motion.dart';
import '../../shared/player_view.dart';
import '../../shared/theme/theme.dart';
import 'player_layout.dart';
import 'player_page.dart';

/// The player as a layer over the app, as in the original app: over
/// everything while watching, docked in the corner when minimised so the
/// app beneath can be browsed. One player instance moves between the two,
/// so playback never restarts.
class PlayerHost extends ConsumerWidget {
  const PlayerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(playerSessionProvider.select((s) => s != null));
    final view = ref.watch(playerViewProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        Inert(inert: open && view != PlayerView.mini, child: child),
        AnimatedSwitcher(
          duration: reduceMotion(context) ? Duration.zero : Motion.reveal,
          switchInCurve: Motion.enter,
          switchOutCurve: Motion.change,
          child: open
              ? _PlayerFrame(key: const ValueKey('player'), view: view)
              : const SizedBox.shrink(key: ValueKey('closed')),
        ),
      ],
    );
  }
}

/// Places the player: filling the app, or a 16:9 card in its corner. Only
/// the player's own rectangle takes pointer input.
class _PlayerFrame extends ConsumerWidget {
  const _PlayerFrame({super.key, required this.view});

  final PlayerView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mini = view == PlayerView.mini;
    final nav = ref.watch(bottomNavExtentProvider);
    final insets = MediaQuery.paddingOf(context);
    final duration = reduceMotion(context) ? Duration.zero : Motion.reveal;
    final floating = context.depth.of(SurfaceDepth.floating);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final rect = mini
            ? dockedPlayerRect(size, insets, nav)
            : Offset.zero & size;
        return Stack(
          children: [
            AnimatedPositioned.fromRect(
              rect: rect,
              duration: duration,
              curve: Motion.change,
              child: AnimatedContainer(
                duration: duration,
                curve: Motion.change,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(mini ? Radii.card : 0),
                  boxShadow: mini ? floating.shadows : const [],
                ),
                // Follows the app's brightness: the player has its own
                // light and dark scheme (PlayerColors).
                child: const Material(
                  type: MaterialType.transparency,
                  child: PlayerPage(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
