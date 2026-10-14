import 'package:flutter/widgets.dart';

import '../shared/theme/theme.dart';
import 'motion.dart';

/// Diagonal wave entrance for a poster grid. Tiles a grid builds together,
/// all at once or as a lazy grid scrolls to them or loads its next page,
/// ripple in from the top-left of their batch; tiles already shown stay
/// put as the grid changes around them.
class GridCascade {
  GridCascade(this.played);

  /// Keys of tiles whose entrance played; the owner decides how long they
  /// are remembered, e.g. until a new search replaces the results.
  final Set<Object> played;

  // First index of the row the current frame's batch started in.
  int? _batch;

  Widget tile({
    required Object key,
    required int index,
    required int columns,
    required Widget child,
  }) {
    final animate = !played.contains(key);
    var wave = 0;
    if (animate) {
      final batch = _batch ??= _startBatch(index - index % columns);
      // Later rows join the crest rather than trailing far behind it.
      wave = ((index - batch) ~/ columns + index % columns).clamp(0, 10);
    }
    return Reveal(
      key: ValueKey(key),
      delay: Duration(milliseconds: 45 * wave),
      offset: Space.s24,
      duration: Motion.reveal * 1.5,
      animate: animate,
      onDone: () => played.add(key),
      child: child,
    );
  }

  int _startBatch(int row) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _batch = null);
    return row;
  }
}
