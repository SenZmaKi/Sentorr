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
    _consumers[owner] = (piece, min(lastPiece, piece + lookahead));
    _apply();
  }

  void release(Cancellation owner) {
    _consumers.remove(owner);
    _apply();
  }

  /// Drops consumers already cancelled, e.g. a closed stream's reads.
  void prune() {
    _consumers.removeWhere((owner, _) => owner.isCancelled);
    _apply();
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
      for (var piece = start; piece <= end; piece++) {
        final urgent = piece == start;
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
