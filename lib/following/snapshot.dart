import 'dart:convert';

import 'models.dart';

/// The followed series and which were unfollowed when, as one device holds
/// them; merging two gives every device the same list.
class FollowedSnapshot {
  const FollowedSnapshot(this.series, this.removals);

  /// Most recently watched first.
  final List<FollowedSeries> series;

  /// When each series, by id, was last unfollowed.
  final Map<String, DateTime> removals;

  /// How long an unfollow is remembered; a device away for longer may
  /// bring the series back.
  static const removalMemory = Duration(days: 90);

  /// This device's records with [other]'s folded in. Each series keeps the
  /// furthest episode either reached and the latest notification choices;
  /// whether it downloads on its own stays this device's. A series stays
  /// unfollowed unless watched or followed again since.
  FollowedSnapshot merge(FollowedSnapshot other) {
    final cutoff = DateTime.now().subtract(removalMemory);
    final removed = <String, DateTime>{};
    for (final r in [...removals.entries, ...other.removals.entries]) {
      final held = removed[r.key];
      if (r.value.isAfter(cutoff) && (held == null || r.value.isAfter(held))) {
        removed[r.key] = r.value;
      }
    }
    final merged = {for (final s in series) s.id: s};
    for (final theirs in other.series) {
      final mine = merged[theirs.id];
      merged[theirs.id] = mine == null
          ? theirs.copyWith(resetAutoDownload: true)
          : mergeFollowed(mine, theirs);
    }
    final kept = merged.values.where((s) {
      final at = removed[s.id];
      return at == null || at.isBefore(s.watchedAt);
    }).toList()..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    return FollowedSnapshot(kept, removed);
  }

  /// Whether [other] holds the same records and removals.
  bool matches(FollowedSnapshot other) =>
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  Map<String, dynamic> toJson() => {
    'series': [for (final s in series) s.toJson()],
    'removed': [
      for (final r in removals.entries)
        {'id': r.key, 'at': r.value.toUtc().toIso8601String()},
    ],
  };

  /// Skips what is not a record, so one bad one costs nothing else.
  static FollowedSnapshot fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const {};
    final series = map['series'], removed = map['removed'];
    return FollowedSnapshot(
      [if (series is List) ...series.map(FollowedSeries.fromJson).nonNulls]
        ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt)),
      {
        if (removed is List)
          for (final r in removed)
            if (r case {'id': final String id, 'at': final String at})
              if (DateTime.tryParse(at) case final time?) id: time.toLocal(),
      },
    );
  }
}

/// One series as two devices hold it, [mine] keeping its own
/// [FollowedSeries.autoDownload].
FollowedSeries mergeFollowed(FollowedSeries mine, FollowedSeries theirs) {
  final order = compareEpisodes(mine.reached, theirs.reached);
  final ahead = order > 0 || (order == 0 && mine.progress >= theirs.progress)
      ? mine
      : theirs;
  final notify = _later(mine.notifyAt, theirs.notifyAt) ? theirs : mine;
  final notified =
      theirs.notified != null &&
          (mine.notified == null || _later(mine.notifiedAt, theirs.notifiedAt))
      ? theirs
      : mine;
  final fresher = theirs.watchedAt.isAfter(mine.watchedAt) ? theirs : mine;
  return FollowedSeries(
    series: fresher.series,
    reached: ahead.reached,
    progress: ahead.progress,
    watchedAt: fresher.watchedAt,
    notified: notified.notified,
    notifiedAt: notified.notifiedAt,
    notify: notify.notify,
    notifyAt: notify.notifyAt,
    autoDownload: mine.autoDownload,
    manual: ahead.manual,
  );
}

/// Whether [b] is later than [a]; a missing time is the earliest.
bool _later(DateTime? a, DateTime? b) =>
    b != null && (a == null || b.isAfter(a));
