import 'dart:async';

import 'package:dio/dio.dart';

import '../torrents/resolution_models.dart';

/// Runs independent discovery together while callers consume results in
/// local, paired-device, torrent order. Search failures stay deferred until
/// the caller actually needs the torrent result.
class SourceLookup<L, P> {
  SourceLookup({
    required Future<L?> Function() local,
    required Future<P?> Function() peer,
    required Future<TorrentResolution> Function(CancelToken) search,
    CancelToken? cancel,
    this.onClose,
  }) {
    this.local = _guard(Future.sync(local));
    this.peer = _guard(Future.sync(peer));
    torrents = _guard(Future.sync(() => search(_cancel)));
    // Every branch can finish before the caller reaches it.
    unawaited(this.local.then<void>((_) {}, onError: (Object _) {}));
    unawaited(this.peer.then<void>((_) {}, onError: (Object _) {}));
    unawaited(torrents.then<void>((_) {}, onError: (Object _) {}));
    cancel?.whenCancel.then((error) => close(error));
  }

  final _cancel = CancelToken();
  final void Function()? onClose;
  bool _closed = false;
  late final Future<L?> local;
  late final Future<P?> peer;
  late final Future<TorrentResolution> torrents;

  Future<T> _guard<T>(Future<T> future) =>
      Future.any([future, _cancel.whenCancel.then<T>((error) => throw error)]);

  CancelToken get searchCancel => _cancel;

  void close([Object? reason]) {
    if (_closed) return;
    _closed = true;
    _cancel.cancel(reason ?? 'Source chosen');
    onClose?.call();
  }
}
