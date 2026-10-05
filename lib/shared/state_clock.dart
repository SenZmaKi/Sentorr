import 'package:flutter_riverpod/flutter_riverpod.dart';

final stateClockProvider = Provider<StateClock>((ref) => StateClock());

/// Lamport revisions are independent of device wall clocks. Every local
/// change advances past all revisions observed in persisted or received state.
class StateClock {
  int _latest = 0;
  int get current => _latest;
  void observe(Iterable<int> revisions) {
    for (final revision in revisions) {
      if (revision > _latest) _latest = revision;
    }
  }

  int next() => ++_latest;
}

/// Version-one state has no revision; preserve its historical time ordering
/// until a new local event upgrades it. Ties on upgraded state are resolved
/// by the caller's deterministic content ordering.
int compareRevision(int a, DateTime? at, int b, DateTime? bt) {
  if (a != 0 || b != 0) return a.compareTo(b);
  return at == null
      ? (bt == null ? 0 : -1)
      : (bt == null ? 1 : at.compareTo(bt));
}

Map<String, int> removalRevisionsFromJson(Object? json) => {
  if (json is List)
    for (final r in json)
      if (r case {'key': final String key, 'revision': final int revision})
        key: revision,
};
