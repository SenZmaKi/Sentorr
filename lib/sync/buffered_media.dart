import 'dart:async';
import 'dart:io';

import 'server.dart';
import 'shared_streams.dart';

/// Relay through the verified torrent byte server, never sparse filesystem reads.
class BufferedMedia {
  BufferedMedia(this.lookup);
  final SharedStream? Function(String) lookup;
  final _leases = <String, BufferedStreamLease>{};
  final _client = HttpClient();
  bool _closed = false;

  Future<void> serve(HttpRequest request, String itemId) async {
    if (_closed) throw const SyncRefusal('Gone', status: 404);
    final hash = request.headers.value('x-sentorr-torrent');
    if (hash == null || !RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(hash)) {
      throw const SyncRefusal('Invalid torrent hash', status: 400);
    }
    final key = '$itemId:${hash.toLowerCase()}';
    var lease = _leases[key];
    if (lease == null) {
      final source = lookup(itemId);
      if (source == null ||
          source.session.state.selectedBytes <= 0 ||
          source.candidate.release.infoHash.toLowerCase() !=
              hash.toLowerCase()) {
        throw const SyncRefusal(
          'Buffered stream is no longer available',
          status: 404,
        );
      }
      lease = BufferedStreamLease(source);
      _leases[key] = lease;
    }
    final active = lease;
    Uri uri;
    try {
      uri = await active.ready;
    } catch (_) {
      if (identical(_leases[key], active)) _leases.remove(key);
      rethrow;
    }
    if (_closed) {
      await active.close();
      throw const SyncRefusal('Gone', status: 404);
    }
    active.acquire();
    try {
      final upstream = await _client.openUrl(request.method, uri);
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) upstream.headers.set(HttpHeaders.rangeHeader, range);
      final incoming = await upstream.close();
      final response = request.response;
      response.statusCode = incoming.statusCode;
      for (final name in [
        HttpHeaders.contentTypeHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
      ]) {
        final value = incoming.headers.value(name);
        if (value != null) response.headers.set(name, value);
      }
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      response.contentLength = incoming.contentLength;
      await response.addStream(incoming);
      await response.close();
    } finally {
      active.release(() {
        if (!identical(_leases[key], active)) return;
        _leases.remove(key);
        unawaited(active.close());
      });
    }
  }

  Future<void> close() async {
    _closed = true;
    _client.close(force: true);
    final pending = _leases.values.toList();
    _leases.clear();
    await Future.wait([
      for (final lease in pending) lease.close().catchError((Object _) {}),
    ]);
  }
}
