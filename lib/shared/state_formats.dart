/// Versions of shared data shapes and merge semantics, independent of app builds.
/// Bump the affected version for an incompatible field or merge-rule change.
abstract final class StateFormats {
  static const watch = 2;
  static const following = 1;
  static const lists = 1;
  static const versions = {
    'watch': watch,
    'following': following,
    'lists': lists,
  };

  static bool accepts(Object? value) =>
      value is Map &&
      value.length == versions.length &&
      versions.entries.every(
        (entry) => value[entry.key] is int && value[entry.key] == entry.value,
      );
}
