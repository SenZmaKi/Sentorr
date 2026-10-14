import 'dart:convert';

import '../shared/state_clock.dart';

/// An explicit season reset, or its later cancellation (null [through]).
class SeasonWatch {
  const SeasonWatch(this.through, this.revision, this.updatedAt);

  /// Episodes watched since the reset. Null restores implicit progress.
  final int? through;
  final int revision;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'through': through,
    'revision': revision,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static SeasonWatch? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final at = DateTime.tryParse(value['updatedAt'] as String? ?? '');
    final through = value['through'];
    if (at == null || (through != null && through is! int)) return null;
    return SeasonWatch(through as int?, value['revision'] as int? ?? 0, at);
  }
}

Map<int, SeasonWatch> mergeSeasonWatches(
  Map<int, SeasonWatch> mine,
  Map<int, SeasonWatch> theirs,
) => {
  for (final season in {...mine.keys, ...theirs.keys})
    season: mine[season] == null
        ? theirs[season]!
        : theirs[season] == null
        ? mine[season]!
        : _latest(mine[season]!, theirs[season]!),
};

SeasonWatch _latest(SeasonWatch mine, SeasonWatch theirs) {
  var order = compareRevision(
    mine.revision,
    mine.updatedAt,
    theirs.revision,
    theirs.updatedAt,
  );
  if (order == 0) {
    order = jsonEncode(mine.toJson()).compareTo(jsonEncode(theirs.toJson()));
  }
  return order > 0 ? mine : theirs;
}
