import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import 'byte_source.dart';
import 'cancellation.dart';
import 'piece_scheduler.dart';
import 'read_waits.dart';
import 'stream_startup.dart';

part 'torrent_preview.dart';

/// One file's bytes for one stream, read through [scheduler], which other
/// streams of the same torrent share.
class TorrentBytes implements ByteSource {
  TorrentBytes(
    this.handle,
    this.file,
    this.readPiece,
    this.scheduler, {
    int readAheadBytes = 16 * 1024 * 1024,
    this.maxCacheBytes = 24 * 1024 * 1024,
    this.readRange,
    this.waitReadable,
    this.isReadable,
  }) : lookahead = max(1, (readAheadBytes / handle.pieceLength).ceil() - 1),
       pieceLength = handle.pieceLength;
  final TorrentHandle handle;
  final TorrentFileEntry file;
  final Future<Uint8List> Function(int, Cancellation) readPiece;
  final PieceScheduler scheduler;
  final int pieceLength, lookahead;
  final Future<Uint8List> Function(int, int, Cancellation)? readRange;
  final Future<void> Function(int, Cancellation)? waitReadable;
  final bool Function(int)? isReadable;
  final _prefetch = Cancellation();
  late final startup = StreamStartup(length);
  final waits = ReadWaits();

  /// The disk window playback wants, held back while playback starts.
  (int, int)? _wanted;

  /// Average media bytes per second, once the caller knows the duration.
  int? _bytesPerSecond;

  void prefetch(int start, int end) {
    final first = (file.offset + start) ~/ pieceLength;
    final last = (file.offset + end - 1) ~/ pieceLength;
    _wanted = (first, last);
    if (!startup.starting) _applyPrefetch();
  }

  void _applyPrefetch() {
    if (_wanted case (final first, final last)) {
      scheduler.demand(_prefetch, first, last, last - first, urgent: false);
    }
  }

  /// Sizes the time-critical window and deadlines to the media's bitrate.
  void pace(int bytesPerSecond) {
    if (bytesPerSecond > 0) _bytesPerSecond = bytesPerSecond;
  }

  /// About 8 seconds of video, so the player's first frames and probe
  /// arrive before anything else competes for peers.
  int get urgentBytes => switch (_bytesPerSecond) {
    final rate? => (rate * 8).clamp(_minUrgentBytes, _maxUrgentBytes),
    null => _minUrgentBytes,
  };
  static const _minUrgentBytes = 2 * 1024 * 1024;
  static const _maxUrgentBytes = 64 * 1024 * 1024;

  int get _urgentPieces => min(16, max(1, (urgentBytes / pieceLength).ceil()));

  /// Milliseconds of playback each piece holds.
  int get _deadlineStep => switch (_bytesPerSecond) {
    final rate? => (pieceLength * 1000 ~/ rate).clamp(100, 4000),
    null => 500,
  };

  /// A new playback position: urgent reads own the bandwidth until the
  /// player has a contiguous start window, then the disk window resumes.
  void restart() {
    startup.begin(urgentBytes);
    scheduler.release(_prefetch);
    _awaitReads();
  }

  int _playbackReads = 0;
  Timer? _idle;

  /// A player that stops reading, e.g. paused right after a seek, has no
  /// start to protect; let the disk window go on without it.
  void _awaitReads() {
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 3), () {
      if (_playbackReads == 0 && startup.starting) {
        startup.abandon();
        _applyPrefetch();
      }
    });
  }

  final _cache = <int, Uint8List>{};
  final _loading = <int, (Cancellation, Future<Uint8List>)>{};
  int _cachedBytes = 0;
  final int maxCacheBytes;
  int get cachedBytes => _cachedBytes;
  @override
  String get name => file.path;
  @override
  int get length => file.size;

  /// A player read: the first one begins the startup window.
  @override
  Future<Uint8List> read(
    int offset,
    int count,
    Cancellation cancellation,
  ) async {
    if (!startup.begun) restart();
    _playbackReads++;
    try {
      return await _read(
        offset,
        count,
        cancellation,
        ahead: max(lookahead, _urgentPieces - 1),
        urgent: true,
        playback: true,
      );
    } finally {
      if (--_playbackReads == 0 && startup.starting) _awaitReads();
    }
  }

  /// Urgent, but not playback: warming a header must not start the hold.
  Future<Uint8List> readHead(
    int offset,
    int count,
    Cancellation cancellation,
  ) => _read(offset, count, cancellation, ahead: lookahead, urgent: true);

  /// Sparse, non-urgent metadata read without expanding the playback window.
  Future<Uint8List> readIndex(
    int offset,
    int count,
    Cancellation cancellation,
  ) => _read(offset, count, cancellation, ahead: 0, urgent: false);

  Future<Uint8List> _read(
    int offset,
    int count,
    Cancellation cancellation, {
    required int ahead,
    required bool urgent,
    bool playback = false,
  }) async {
    if (offset < 0 || count < 0 || offset + count > length) {
      throw RangeError('Read outside selected file');
    }
    cancellation.check();
    Uint8List? output;
    for (var copied = 0; copied < count;) {
      cancellation.check();
      final absolute = file.offset + offset + copied;
      final piece = absolute ~/ pieceLength;
      scheduler.demand(
        cancellation,
        piece,
        (file.offset + length - 1) ~/ pieceLength,
        ahead,
        urgent: urgent,
        urgentPieces: urgent && _bytesPerSecond != null ? _urgentPieces : null,
        deadlineStep: _deadlineStep,
      );
      final waited = playback ? waits.begin(piece) : (Stopwatch()..start());
      final Uint8List data;
      try {
        if (readRange != null) {
          await cancellation.wait(waitReadable!(piece, cancellation));
          // Bound each filesystem operation even for unusually large pieces.
          final take = min(
            count - copied,
            min(64 * 1024, pieceLength - absolute % pieceLength),
          );
          data = await cancellation.wait(
            readRange!(offset + copied, take, cancellation),
          );
        } else {
          data = await cancellation.wait(_piece(piece));
        }
      } catch (_) {
        if (playback) waits.abandon(piece, waited);
        rethrow;
      }
      if (playback) waits.end(piece, waited);
      cancellation.check();
      final within = readRange != null ? 0 : absolute % pieceLength;
      final take = min(count - copied, data.length - within);
      if (take <= 0) throw StateError('Invalid native piece layout');
      if (playback && startup.served(piece, offset + copied, take, waited)) {
        _applyPrefetch();
      }
      if (copied == 0 && take == count) {
        // Socket writes can borrow a piece; eviction only drops our reference.
        // Keep callers from modifying the cached bytes through this view.
        return Uint8List.sublistView(
          data,
          within,
          within + take,
        ).asUnmodifiableView();
      }
      output ??= Uint8List(count);
      output.setRange(copied, copied + take, data, within);
      copied += take;
    }
    return output ?? Uint8List(0);
  }

  (int, Uint8List)? _previewPiece;

  Future<Uint8List> _piece(int piece) async {
    final cached = _cache.remove(piece);
    if (cached != null) {
      _cache[piece] = cached;
      return cached;
    }
    if (_loading.containsKey(piece)) return _loading[piece]!.$2;
    final cancellation = Cancellation();
    final future = _load(piece, cancellation);
    _loading[piece] = (cancellation, future);
    try {
      return await future;
    } finally {
      if (_loading[piece]?.$2 == future) _loading.remove(piece);
    }
  }

  Future<Uint8List> _load(int piece, Cancellation cancellation) async {
    final data = await readPiece(piece, cancellation);
    cancellation.check();
    if (data.length != handle.pieceSize(piece)) {
      throw StateError('Unexpected native piece size');
    }
    if (data.length <= maxCacheBytes) {
      while (_cachedBytes + data.length > maxCacheBytes && _cache.isNotEmpty) {
        _cachedBytes -= _cache.remove(_cache.keys.first)!.length;
      }
      _cache[piece] = data;
      _cachedBytes += data.length;
    }
    return data;
  }

  @override
  void release(Cancellation cancellation) {
    scheduler.release(cancellation);
    for (final piece in _loading.keys.toList()) {
      if (!scheduler.needs(piece)) _loading.remove(piece)!.$1.cancel();
    }
  }

  void close() {
    _idle?.cancel();
    _prefetch.cancel();
    scheduler.release(_prefetch);
    for (final loading in _loading.values) {
      loading.$1.cancel();
    }
    _loading.clear();
    _previewPiece = null;
    _cache.clear();
    _cachedBytes = 0;
    scheduler.prune();
  }
}
