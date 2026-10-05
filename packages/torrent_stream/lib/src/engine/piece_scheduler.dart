import 'dart:math';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import 'cancellation.dart';

/// Consumers own moving windows, never an entire open-ended HTTP range. One
/// scheduler serves every stream of a torrent; pieces outside all windows
/// return to [base], the priority the torrent's wanted files give them.
class PieceScheduler {
  PieceScheduler(this.handle, {int Function(int piece)? base})
    : base = base ?? ((_) => 0);
  final TorrentHandle handle;
  int Function(int piece) base;
  final _consumers = <Cancellation, (int, int)>{};
  final _active = <int>{};
  final _deadlines = <int, int>{};
  final _priorities = <int, int>{};
  int get urgentPieces => _deadlines.length;
  bool needs(int piece) => _active.contains(piece);
  void demand(Cancellation owner, int piece, int lastPiece, int lookahead) {
    final window = (piece, min(lastPiece, piece + lookahead));
    // HTTP reads within the same piece keep the same demand window.
    if (_consumers[owner] == window &&
        !_consumers.keys.any((consumer) => consumer.isCancelled)) {
      return;
    }
    _consumers[owner] = window;
    _apply();
  }

  void release(Cancellation owner) {
    if (_consumers.remove(owner) != null) _apply();
  }

  /// Drops consumers already cancelled, e.g. a closed stream's reads.
  void prune() {
    final before = _consumers.length;
    _consumers.removeWhere((owner, _) => owner.isCancelled);
    if (_consumers.length != before) _apply();
  }

  /// Sets every window again, after file priorities replaced them.
  void reapply() {
    _deadlines.clear();
    _priorities.clear();
    _apply();
  }

  void _apply() {
    final deadlines = <int, int>{};
    final priorities = <int, int>{};
    for (final entry in _consumers.entries) {
      if (entry.key.isCancelled) continue;
      final (start, end) = entry.value;
      // Keep a bounded upcoming window time-critical, rather than waiting
      // for the player to block on each next piece. Large pieces shrink it.
      final urgentCount = min(
        4,
        max(1, (2 * 1024 * 1024 / handle.pieceLength).ceil()),
      );
      for (var piece = start; piece <= end; piece++) {
        final urgent = piece - start < urgentCount;
        priorities[piece] = max(
          priorities[piece] ?? base(piece),
          urgent ? 7 : 1,
        );
        if (urgent) {
          final deadline = (piece - start) * 500;
          deadlines[piece] = min(deadlines[piece] ?? deadline, deadline);
        }
      }
    }
    for (final piece in _active.difference(priorities.keys.toSet())) {
      handle.resetPieceDeadline(piece);
      handle.setPiecePriority(piece, base(piece));
    }
    for (final piece in _deadlines.keys.toSet().difference(
      deadlines.keys.toSet(),
    )) {
      handle.resetPieceDeadline(piece);
    }
    for (final entry in priorities.entries) {
      if (_priorities[entry.key] != entry.value) {
        handle.setPiecePriority(entry.key, entry.value);
      }
    }
    for (final entry in deadlines.entries) {
      if (_deadlines[entry.key] != entry.value) {
        handle.setPieceDeadline(entry.key, entry.value);
      }
    }
    _deadlines
      ..clear()
      ..addAll(deadlines);
    _priorities
      ..clear()
      ..addAll(priorities);
    _active
      ..clear()
      ..addAll(priorities.keys);
  }

  void clear() {
    _consumers.clear();
    _apply();
  }
}
