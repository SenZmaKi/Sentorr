import 'package:flutter/material.dart';

import '../../components/motion.dart';
import '../../shared/theme/theme.dart';
import 'player_ui.dart';

/// Acknowledges a command in the picture: a glyph in a dark disc that swells
/// slightly and fades, centred, or toward the side a seek moved.
class CenterFeedback extends StatefulWidget {
  const CenterFeedback({super.key});

  @override
  State<CenterFeedback> createState() => _CenterFeedbackState();
}

class _CenterFeedbackState extends State<CenterFeedback>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  PlayerFeedback? _shown;
  bool _first = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PlayerUiScope.of(context).feedback;
    // Feedback from before this mounted (e.g. a mini-player tap) is stale.
    if (_first) {
      _first = false;
      _shown = next;
      return;
    }
    if (next == null || identical(next, _shown)) return;
    _shown = next;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _shown;
    if (f == null) return const SizedBox.shrink();
    final still = reduceMotion(context);
    return IgnorePointer(
      child: Align(
        alignment: Alignment(f.side == null ? 0 : f.side! * 0.6, 0),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            if (_c.isDismissed || t >= 1) return const SizedBox.shrink();
            // Quick in, hold, slow out.
            final opacity = t < 0.15
                ? t / 0.15
                : t < 0.55
                ? 1.0
                : 1 - (t - 0.55) / 0.45;
            final scale = still
                ? 1.0
                : 0.9 + 0.15 * Curves.easeOut.transform(t);
            return Opacity(
              opacity: opacity.clamp(0, 1),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.player.controlSurface,
                ),
                child: Icon(f.icon, size: 36, color: context.player.foreground),
              ),
              if (f.label != null) ...[
                const SizedBox(height: Space.s8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.player.scrim,
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.s12,
                      vertical: Space.s4,
                    ),
                    child: Text(
                      f.label!,
                      style: context.type.label.copyWith(
                        color: context.player.foreground,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
