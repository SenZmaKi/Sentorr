import 'package:flutter/material.dart';

import '../../components/interactive.dart';
import '../../components/motion.dart';
import '../../shared/theme/theme.dart';

/// One dot per featured title. The current one is a wider track that fills
/// as its turn runs, so position is not conveyed by color alone.
class SpotlightPager extends StatelessWidget {
  const SpotlightPager({
    super.key,
    required this.titles,
    required this.index,
    required this.progress,
    required this.onSelect,
    this.indicator = false,
  });

  /// Each spotlit title's name, for its dot's accessible label.
  final List<String> titles;
  final int index;
  final Animation<double> progress;
  final ValueChanged<int> onSelect;

  /// Dots without their own targets, set close together; assistive
  /// technology steps through titles as it would a slider.
  final bool indicator;

  Widget _dot(BuildContext context, int n, {bool hovered = false}) =>
      AnimatedContainer(
        duration: Motion.reveal,
        curve: Motion.change,
        width: n == index ? Space.s32 : Space.s8,
        height: Space.s8,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: hovered
              ? OverlayColors.foregroundSecondary
              : OverlayColors.inactiveTrack,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: n != index
            ? null
            : AnimatedBuilder(
                animation: progress,
                builder: (context, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: reduceMotion(context) ? 1 : progress.value,
                  child: const ColoredBox(color: OverlayColors.foreground),
                ),
              ),
      );

  @override
  Widget build(BuildContext context) {
    final count = titles.length;
    if (indicator) {
      return Semantics(
        label: 'Featured title',
        value: '${index + 1} of $count, ${titles[index]}',
        increasedValue: '${(index + 1) % count + 1} of $count',
        decreasedValue: '${(index - 1) % count + 1} of $count',
        onIncrease: () => onSelect((index + 1) % count),
        onDecrease: () => onSelect((index - 1) % count),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.s8,
          children: [for (var n = 0; n < count; n++) _dot(context, n)],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (n, t) in titles.indexed)
          Interactive(
            onTap: () => onSelect(n),
            selected: n == index,
            semanticLabel: 'Feature $t',
            borderRadius: Radii.full,
            focusColor: OverlayColors.focus,
            // 24 on pointer; 48 on touch, keeping the 8 dot.
            builder: (context, s) => MinTarget(
              child: Padding(
                padding: const EdgeInsets.all(Space.s8),
                child: _dot(context, n, hovered: s.hovered),
              ),
            ),
          ),
      ],
    );
  }
}
