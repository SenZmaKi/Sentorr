import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';

import '../models.dart';
import 'source.dart';

/// Specialized adapters declare their media condition separately from parsing.
abstract class SpecializedTorrentSource implements DiagnosticTorrentSource {
  bool appliesTo(TorrentQuery query);

  @override
  bool supports(TorrentQuery query) => appliesTo(query);

  @override
  Future<List<TorrentRelease>> search(
    TorrentQuery query, {
    CancelToken? cancelToken,
  }) => searchWithDiagnostics(
    query,
    cancelToken: cancelToken,
    onRejected: (_) {},
  );
}

/// Share one gate per specialized source across adapter instances and mirrors.
/// Queued cancellation removes work before it can consume a permit.
class SourceRequestGate {
  SourceRequestGate(this.limit) {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
  }
  final int limit;
  int _active = 0;
  final _queue = Queue<Completer<void>>();

  Future<T> run<T>(Future<T> Function() request, CancelToken? token) async {
    if (token?.isCancelled ?? false) throw token!.cancelError!;
    if (_active < limit) {
      _active++;
    } else {
      final waiter = Completer<void>();
      _queue.add(waiter);
      unawaited(
        token?.whenCancel.then((error) {
          if (_queue.remove(waiter)) waiter.completeError(error);
        }),
      );
      await waiter.future;
    }
    try {
      if (token?.isCancelled ?? false) throw token!.cancelError!;
      return await request();
    } finally {
      if (_queue.isEmpty) {
        _active--;
      } else {
        _queue.removeFirst().complete();
      }
    }
  }
}
