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
  final _consumers = <Cancellation, _Window>{};
  final _background = <Cancellation>{};
  final _active = <int>{};
  final _deadlines = <int, int>{};
  final _priorities = <int, int>{};
  int get urgentPieces => _deadlines.length;
  bool needs(int piece) => _active.contains(piece);

  /// Each live consumer's window: first and last piece, and how many lead
  /// pieces carry deadlines.
  List<({int first, int last, int urgent, bool background})> get windows => [
    for (final MapEntry(key: owner, value: w) in _consumers.entries)
      if (!owner.isCancelled)
        (
          first: w.$1,
          last: w.$2,
          urgent: w.$3,
          background: _background.contains(owner),
        ),
  ];
  void demand(
    Cancellation owner,
    int piece,
    int lastPiece,
    int lookahead, {
    bool urgent = true,
    int? urgentPieces,
    int deadlineStep = 500,
  }) {
    final changedUrgency = urgent
        ? _background.remove(owner)
        : _background.add(owner);
    final window = (
      piece,
      min(lastPiece, piece + lookahead),
      // Without a known bitrate, about 2 MiB of video is time-critical.
      urgentPieces ??
          min(4, max(1, (2 * 1024 * 1024 / handle.pieceLength).ceil())),
      deadlineStep,
    );
    // HTTP reads within the same piece keep the same demand window.
    if (!changedUrgency &&
        _consumers[owner] == window &&
        !_consumers.keys.any((consumer) => consumer.isCancelled)) {
      return;
    }
    _consumers[owner] = window;
    _apply();
  }

  void release(Cancellation owner) {
    _background.remove(owner);
    if (_consumers.remove(owner) != null) _apply();
  }

  /// Drops consumers already cancelled, e.g. a closed stream's reads.
  void prune() {
    final before = _consumers.length;
    _consumers.removeWhere((owner, _) => owner.isCancelled);
    _background.removeWhere((owner) => owner.isCancelled);
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
      // Keep a bounded upcoming window time-critical, rather than waiting
      // for the player to block on each next piece. Deadlines are spaced by
      // when playback reaches each piece.
      final (start, end, urgentCount, step) = entry.value;
      for (var piece = start; piece <= end; piece++) {
        final urgent =
            !_background.contains(entry.key) && piece - start < urgentCount;
        // Read-ahead stays ahead of files downloaded in full (priority 4),
        // including subtitle sidecars; only imminent video bytes get deadlines.
        priorities[piece] = max(
          priorities[piece] ?? base(piece),
          urgent ? 7 : 5,
        );
        if (urgent) {
          final deadline = (piece - start) * step;
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
    _background.clear();
    _apply();
  }
}

/// First and last piece, how many lead pieces get deadlines, and their
/// spacing in milliseconds.
typedef _Window = (int, int, int, int);
