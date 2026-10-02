import 'dart:math';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import 'cancellation.dart';
import 'streaming_policy.dart';

/// Consumers own moving windows, never an entire open-ended HTTP range.
class PieceScheduler {
  PieceScheduler(this.handle, {this.lookahead = 4});
  final TorrentHandle handle;
  final int lookahead;
  final _consumers = <Cancellation, (int, int)>{};
  final _active = <int>{};
  final _deadlines = <int, int>{};
  final _priorities = <int, int>{};
  final narrow = StreamingPolicy.narrowUrgent;
  int get urgentPieces => _deadlines.length;
  bool needs(int piece) => _active.contains(piece);
  void demand(Cancellation owner, int piece, int lastPiece) {
    _consumers[owner] = (piece, min(lastPiece, piece + lookahead));
    _apply();
  }

  void release(Cancellation owner) {
    _consumers.remove(owner);
    _apply();
  }

  void _apply() {
    final deadlines = <int, int>{};
    final priorities = <int, int>{};
    for (final entry in _consumers.entries) {
      if (entry.key.isCancelled) continue;
      final (start, end) = entry.value;
      for (var piece = start; piece <= end; piece++) {
        final urgent = !narrow || piece == start;
        priorities[piece] = max(priorities[piece] ?? 0, urgent ? 7 : 1);
        if (urgent) {
          final deadline = (piece - start) * 500;
          deadlines[piece] = min(deadlines[piece] ?? deadline, deadline);
        }
      }
    }
    for (final piece in _active.difference(priorities.keys.toSet())) {
      handle.resetPieceDeadline(piece);
      handle.setPiecePriority(piece, 0);
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
