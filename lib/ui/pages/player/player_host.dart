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

/// Places the player: filling the app, or a 16:9 card in a bottom corner.
/// The card can be dragged anywhere and, like YouTube's, snaps to the
/// nearest corner on release: on each axis, the half its centre ended in,
/// or the way it was flung. Only the player's own rectangle takes pointer input.
class _PlayerFrame extends ConsumerStatefulWidget {
  const _PlayerFrame({super.key, required this.view});

  final PlayerView view;

  @override
  ConsumerState<_PlayerFrame> createState() => _PlayerFrameState();
}

class _PlayerFrameState extends ConsumerState<_PlayerFrame> {
  /// Flings faster than this, in logical pixels a second, pick the side
  /// on their axis.
  static const _flingVelocity = 400.0;

  DockCorner _corner = DockCorner.bottomRight;

  /// Where the card is while a drag is in progress.
  Rect? _drag;

  void _move(Offset delta, Size size) {
    final r = _drag!.shift(delta);
    setState(
      () => _drag =
          Offset(
            r.left.clamp(0, size.width - r.width),
            r.top.clamp(0, size.height - r.height),
          ) &
          r.size,
    );
  }

  void _release(Offset velocity, Size size) {
    final r = _drag;
    if (r == null) return;
    bool lowSide(double v, double centre, double extent) =>
        v.abs() > _flingVelocity ? v < 0 : centre < extent / 2;
    setState(() {
      _corner = DockCorner.of(
        left: lowSide(velocity.dx, r.center.dx, size.width),
        top: lowSide(velocity.dy, r.center.dy, size.height),
      );
      _drag = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mini = widget.view == PlayerView.mini;
    final nav = ref.watch(bottomNavExtentProvider);
    final insets = MediaQuery.paddingOf(context);
    final motion = reduceMotion(context) ? Duration.zero : Motion.reveal;
    final floating = context.depth.of(SurfaceDepth.floating);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final docked = dockedPlayerRect(size, insets, nav, corner: _corner);
        final rect = !mini ? Offset.zero & size : _drag ?? docked;
        // The card follows the pointer exactly, then eases into its corner.
        final duration = _drag != null ? Duration.zero : motion;
        return Stack(
          children: [
            AnimatedPositioned.fromRect(
              rect: rect,
              duration: duration,
              curve: Motion.change,
              child: GestureDetector(
                // Picks the card up where it is, even mid-snap.
                onPanStart: mini
                    ? (d) => setState(() {
                        final frame = context.findRenderObject()! as RenderBox;
                        final origin = frame.globalToLocal(
                          d.globalPosition - d.localPosition,
                        );
                        _drag = origin & docked.size;
                      })
                    : null,
                onPanUpdate: mini ? (d) => _move(d.delta, size) : null,
                onPanEnd: mini
                    ? (d) => _release(d.velocity.pixelsPerSecond, size)
                    : null,
                onPanCancel: mini ? () => _release(Offset.zero, size) : null,
                child: AnimatedContainer(
                  duration: motion,
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
            ),
          ],
        );
      },
    );
  }
}
