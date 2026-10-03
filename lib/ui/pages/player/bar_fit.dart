import '../../shared/theme/theme.dart';

/// The bottom bar's optional controls. Play/pause and the clock always
/// show; these show while there is room and otherwise move to More.
enum BarControl {
  fullscreen,
  settings,

  /// The episodes chip: the queue's opener, which needs a label's room.
  episodes,
  next,
  captions,
  torrents,
  previous,
  popOut,
  volume;

  /// Most wanted first: what gives way last on a narrow bar.
  static const priority = values;

  /// Room the control takes in the row, its gap included.
  double get extent => switch (this) {
    // The chip's least useful width plus the gap after it.
    episodes => _chipMin + Space.s16,
    volume => PlayerMetrics.control + Space.s8,
    _ => PlayerMetrics.control,
  };

  static const _chipMin = 96.0;
}

/// Which [available] controls fit in [width] once [fixed] (play, clock and
/// any badges) is placed, by [BarControl.priority]. Controls that do not
/// fit go to [overflow], in the bar's order, and a More control takes room
/// from the rest; every control stays reachable.
({Set<BarControl> shown, List<BarControl> overflow}) fitBar({
  required Set<BarControl> available,
  required double width,
  required double fixed,
}) {
  double total(Iterable<BarControl> cs) =>
      cs.fold(0, (sum, c) => sum + c.extent);
  if (fixed + total(available) <= width) {
    return (shown: available, overflow: const []);
  }
  var room = width - fixed - PlayerMetrics.control;
  final shown = <BarControl>{};
  for (final c in BarControl.priority) {
    if (!available.contains(c) || c.extent > room) continue;
    shown.add(c);
    room -= c.extent;
  }
  return (
    shown: shown,
    overflow: [
      for (final c in BarControl.values)
        if (available.contains(c) && !shown.contains(c)) c,
    ],
  );
}
