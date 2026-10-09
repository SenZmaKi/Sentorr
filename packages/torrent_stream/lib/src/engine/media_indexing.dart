import 'dart:async';
import 'dart:typed_data';

import '../media/container_index.dart';
import '../media/media_index.dart';
import 'cancellation.dart';

/// A slow metadata read is temporary, not a permanent unsupported format.
/// Retry only after download progress, with one attempt and bounded reads.
class MediaIndexing {
  MediaIndexing(
    this.length,
    this.read,
    this.release, {
    this.timeout = const Duration(seconds: 30),
    this.retryDelay = const Duration(seconds: 10),
  });
  final int length;
  final Future<Uint8List> Function(int, int, Cancellation) read;
  final void Function(Cancellation) release;
  final Duration timeout, retryDelay;
  MediaIndex? index;
  String status = 'pending';
  Cancellation? _cancel;
  bool _closed = false, _unsupported = false;
  int _attemptBytes = -1, _attempt = 0;
  DateTime? _retryAt;

  void refresh(int verifiedBytes) {
    if (_closed ||
        _unsupported ||
        index != null ||
        _cancel != null ||
        verifiedBytes <= _attemptBytes ||
        (_retryAt != null && DateTime.now().isBefore(_retryAt!))) {
      return;
    }
    _attemptBytes = verifiedBytes;
    final cancel = _cancel = Cancellation();
    status = 'reading index (attempt ${++_attempt})';
    unawaited(_run(cancel));
  }

  Future<void> _run(Cancellation cancel) async {
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      cancel.cancel();
    });
    try {
      final result = await containerIndex(
        length,
        (offset, count) => read(offset, count, cancel),
      );
      cancel.check();
      index = result;
      _unsupported = result == null;
      status = result == null
          ? 'unsupported or incomplete container index'
          : 'ready: ${result.intervals.length} intervals';
    } catch (error) {
      if (!_closed) {
        status = timedOut
            ? 'metadata timed out; waiting for download progress to retry'
            : 'metadata read failed: $error; waiting for download progress to retry';
        _retryAt = DateTime.now().add(retryDelay);
      }
    } finally {
      timer.cancel();
      release(cancel);
      if (identical(_cancel, cancel)) _cancel = null;
    }
  }

  void close() {
    _closed = true;
    _cancel?.cancel();
  }
}
