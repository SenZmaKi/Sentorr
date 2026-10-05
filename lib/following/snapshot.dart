import 'dart:convert';

import 'models.dart';
import '../shared/state_clock.dart';

/// The followed series and which were unfollowed when, as one device holds
/// them; merging two gives every device the same list.
class FollowedSnapshot {
  const FollowedSnapshot(
    this.series,
    this.removals, [
    this.removalRevisions = const {},
  ]);

  /// Most recently watched first.
  final List<FollowedSeries> series;

  /// When each series, by id, was last unfollowed.
  final Map<String, DateTime> removals;
  final Map<String, int> removalRevisions;

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
    final revisions = <String, int>{};
    for (final source in [this, other]) {
      for (final r in source.removals.entries) {
        final revision = source.removalRevisions[r.key] ?? 0;
        if (r.value.isAfter(cutoff) &&
            (!removed.containsKey(r.key) ||
                compareRevision(
                      revision,
                      r.value,
                      revisions[r.key] ?? 0,
                      removed[r.key],
                    ) >
                    0 ||
                (revision == (revisions[r.key] ?? 0) &&
                    r.value.isAfter(removed[r.key]!)))) {
          removed[r.key] = r.value;
          revisions[r.key] = revision;
        }
      }
    }
    bool alive(FollowedSeries s) {
      final at = removed[s.id];
      return at == null ||
          compareRevision(s.revision, s.watchedAt, revisions[s.id] ?? 0, at) >
              0;
    }

    final local = {for (final s in series) s.id: s};
    final contributions = <String, List<FollowedSeries>>{};
    for (final record in [...series, ...other.series]) {
      for (final value
          in record.versions.isEmpty ? [record] : record.versions) {
        if (alive(value)) {
          (contributions[value.id] ??= []).add(value);
        }
      }
    }
    final merged = {
      for (final entry in contributions.entries)
        entry.key: mergeFollowedMany(entry.value).copyWith(
          autoDownload: local[entry.key]?.autoDownload,
          resetAutoDownload: local[entry.key]?.autoDownload == null,
        ),
    };
    final kept = merged.values.where((s) {
      final at = removed[s.id];
      return at == null ||
          compareRevision(s.revision, s.watchedAt, revisions[s.id] ?? 0, at) >
              0;
    }).toList()..sort((a, b) => compareFollowed(b, a));
    return FollowedSnapshot(kept, removed, revisions);
  }

  /// Whether [other] holds the same records and removals.
  bool matches(FollowedSnapshot other) =>
      jsonEncode(canonicalJson()) == jsonEncode(other.canonicalJson());

  Map<String, dynamic> canonicalJson() => {
    ...toJson(),
    'series': [
      for (final s in series.toList()..sort(compareFollowed)) s.toJson(),
    ],
  };

  Map<String, dynamic> toJson() => {
    'series': [for (final s in series) s.toJson()],
    'removed': [
      for (final id in removals.keys.toList()..sort())
        {
          'id': id,
          'at': removals[id]!.toUtc().toIso8601String(),
          if ((removalRevisions[id] ?? 0) != 0)
            'revision': removalRevisions[id]!,
        },
    ],
  };

  /// Skips what is not a record, so one bad one costs nothing else.
  static FollowedSnapshot fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const {};
    final series = map['series'], removed = map['removed'];
    return FollowedSnapshot(
      [if (series is List) ...series.map(FollowedSeries.fromJson).nonNulls]
        ..sort((a, b) => compareFollowed(b, a)),
      {
        if (removed is List)
          for (final r in removed)
            if (r case {'id': final String id, 'at': final String at})
              if (DateTime.tryParse(at) case final time?) id: time.toLocal(),
      },
      {
        if (removed is List)
          for (final r in removed)
            if (r case {'id': final String id, 'revision': final int revision})
              id: revision,
      },
    );
  }
}

/// One series as two devices hold it, [mine] keeping its own
/// [FollowedSeries.autoDownload].
FollowedSeries mergeFollowed(FollowedSeries mine, FollowedSeries theirs) =>
    mergeFollowedMany([mine, theirs]).copyWith(
      autoDownload: mine.autoDownload,
      resetAutoDownload: mine.autoDownload == null,
    );

FollowedSeries mergeFollowedMany(Iterable<FollowedSeries> values) {
  final records = <String, FollowedSeries>{};
  for (final record in values) {
    for (final v in record.versions.isEmpty ? [record] : record.versions) {
      records[jsonEncode(v.toJson()..remove('autoDownload'))] = v;
    }
  }
  final keys = records.keys.toList()..sort();
  final versions = [
    for (final key in keys) records[key]!.copyWith(resetAutoDownload: true),
  ];
  return versions
      .reduce(_mergeFields)
      .copyWith(versions: versions.length == 1 ? const [] : versions);
}

FollowedSeries _mergeFields(FollowedSeries mine, FollowedSeries theirs) {
  final order = compareEpisodes(mine.reached, theirs.reached);
  final ahead =
      order > 0 ||
          (order == 0 &&
              (mine.progress > theirs.progress ||
                  (mine.progress == theirs.progress && !mine.manual)))
      ? mine
      : theirs;
  final notifyOrder = compareRevision(
    mine.notifyRevision,
    mine.notifyAt,
    theirs.notifyRevision,
    theirs.notifyAt,
  );
  final notify = notifyOrder < 0 || (notifyOrder == 0 && !theirs.notify)
      ? theirs
      : mine;
  final notified =
      theirs.notified != null &&
          (mine.notified == null ||
              (compareRevision(
                        mine.notifiedRevision,
                        mine.notifiedAt,
                        theirs.notifiedRevision,
                        theirs.notifiedAt,
                      ) <
                      0 ||
                  (compareRevision(
                            mine.notifiedRevision,
                            mine.notifiedAt,
                            theirs.notifiedRevision,
                            theirs.notifiedAt,
                          ) ==
                          0 &&
                      theirs.notified!.compareTo(mine.notified!) > 0)))
      ? theirs
      : mine;
  final fresher = compareFollowed(theirs, mine) > 0 ? theirs : mine;
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

    revision: fresher.revision,
    notifyRevision: notify.notifyRevision,
    notifiedRevision: notified.notifiedRevision,
  );
}

int compareFollowed(FollowedSeries a, FollowedSeries b) {
  final time = compareRevision(
    a.revision,
    a.watchedAt,
    b.revision,
    b.watchedAt,
  );
  if (time != 0) return time;
  final left = a.toJson()..remove('autoDownload');
  final right = b.toJson()..remove('autoDownload');
  return jsonEncode(left).compareTo(jsonEncode(right));
}
