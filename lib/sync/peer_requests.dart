/// Generations invalidate late results across unpairing and newer libraries.
class PeerRequests {
  final _epochs = <String, int>{};
  final _libraries = <String, int>{};
  final refreshing = <String>{};

  int epoch(String id) => _epochs[id] ?? 0;
  int libraryVersion(String id) => _libraries[id] ?? 0;
  void invalidateLibrary(String id) => _libraries[id] = libraryVersion(id) + 1;

  void forget(String id) {
    _epochs[id] = epoch(id) + 1;
    invalidateLibrary(id);
  }
}
