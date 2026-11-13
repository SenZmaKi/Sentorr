import 'dart:async';
import 'dart:io';

import 'server.dart';
import 'shared_streams.dart';

/// Relay through the verified torrent byte server, never sparse filesystem reads.
class BufferedMedia {
  BufferedMedia(this.lookup, {this.restore});
  final Future<SharedStream?> Function(String itemId, String hash)? restore;
  final _opening = <String, Future<BufferedStreamLease>>{};
  final _versions = <String, String>{};
  final SharedStream? Function(String) lookup;
  final _leases = <String, BufferedStreamLease>{};
  final _clients = <HttpClient>{};
  bool _closed = false;

  Future<void> serve(HttpRequest request, String itemId) async {
    if (_closed) throw const SyncRefusal('Gone', status: 404);
    final hash = request.headers.value('x-sentorr-torrent');
    if (hash == null || !RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(hash)) {
      throw const SyncRefusal('Invalid torrent hash', status: 400);
    }
    final key = '$itemId:${hash.toLowerCase()}';
    var active = _leases[key];
    if (active == null) {
      final pending = _opening.putIfAbsent(key, () => _open(itemId, hash, key));
      try {
        active = await pending;
      } finally {
        if (identical(_opening[key], pending)) _opening.remove(key);
      }
    }
    final version = '"${_versions[key]}"';
    final expected = request.headers.value(HttpHeaders.ifMatchHeader);
    if (expected != null && expected != version) {
      active.acquire();
      active.release(() => _expire(key, active!));
      request.response.statusCode = HttpStatus.preconditionFailed;
      return request.response.close();
    }
    final held = active;
    held.acquire();
    final client = HttpClient();
    _clients.add(client);
    unawaited(
      request.response.done.then<void>(
        (_) => client.close(force: true),
        onError: (Object _) => client.close(force: true),
      ),
    );
    try {
      final uri = await held.ready.catchError((Object error) {
        if (identical(_leases[key], held)) {
          _leases.remove(key);
          _versions.remove(key);
        }
        throw error;
      });
      if (_closed) throw const SyncRefusal('Gone', status: 404);
      final upstream = await client.openUrl(request.method, uri);
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
      response.headers.set(HttpHeaders.etagHeader, version);
      response.contentLength = incoming.contentLength;
      await response.addStream(incoming);
      await response.close();
    } finally {
      client.close(force: true);
      _clients.remove(client);
      held.release(() => _expire(key, held));
    }
  }

  void _expire(String key, BufferedStreamLease lease) {
    if (!identical(_leases[key], lease)) return;
    _leases.remove(key);
    _versions.remove(key);
    unawaited(lease.close());
  }

  Future<BufferedStreamLease> _open(
    String itemId,
    String hash,
    String key,
  ) async {
    var source = lookup(itemId);
    if (source?.candidate.release.infoHash.toLowerCase() !=
        hash.toLowerCase()) {
      source = null;
    }
    final restored = source == null;
    source ??= await restore?.call(itemId, hash);
    if (source == null ||
        source.candidate.release.infoHash.toLowerCase() != hash.toLowerCase()) {
      throw const SyncRefusal(
        'Cached stream is no longer available',
        status: 404,
      );
    }
    final lease = restored
        ? BufferedStreamLease.owned(source)
        : BufferedStreamLease(source);
    if (_closed) {
      await lease.close();
      throw const SyncRefusal('Gone', status: 404);
    }
    _leases[key] = lease;
    _versions[key] = source.offer.bufferedVersion;
    return lease;
  }

  Future<void> close() async {
    _closed = true;
    for (final client in _clients) {
      client.close(force: true);
    }
    _clients.clear();
    final pending = _leases.values.toList();
    _leases.clear();
    _versions.clear();
    await Future.wait([
      for (final opening in _opening.values.toList())
        opening.then<void>((lease) => lease.close(), onError: (Object _) {}),
      for (final lease in pending) lease.close().catchError((Object _) {}),
    ]);
  }
}
