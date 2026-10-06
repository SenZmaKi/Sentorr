import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps asynchronous player cleanup awaitable after its UI provider goes away.
class PlayerLifecycle {
  final _players = <Future<void> Function()>{};

  void register(Future<void> Function() dispose) => _players.add(dispose);

  void unregister(Future<void> Function() dispose) => _players.remove(dispose);

  Future<void> dispose() async {
    await Future.wait(_players.toList().map((dispose) => dispose()));
  }
}

final playerLifecycleProvider = Provider((ref) => PlayerLifecycle());
