import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'byte_source.dart';
import 'cancellation.dart';
import 'http_range.dart';

class MediaServer {
  MediaServer(this.source, {this.onEvent});
  final ByteSource source;
  final void Function(Map<String, Object?>)? onEvent;
  final _requests = <Cancellation>{};
  final _sockets = <Cancellation, Socket>{};
  HttpServer? _server;
  late Uri uri;
  int servedBytes = 0;
  int requestCount = 0;
  bool _closed = false;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random.secure();
    final token = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    uri = Uri.http('127.0.0.1:${_server!.port}', '/$token/media');
    _server!.listen(
      (request) => unawaited(_handle(request)),
      onError: (Object error) {
        onEvent?.call({'event': 'connection-ended', 'reason': '$error'});
      },
    );
  }

  Future<void> _handle(HttpRequest request) async {
    // Disconnects can also occur while writing rejection/HEAD headers or
    // closing a response, outside the body-serving catch below.
    try {
      await _serve(request);
    } on IOException catch (error) {
      onEvent?.call({'event': 'connection-ended', 'reason': '$error'});
    }
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    unawaited(response.done.then((_) {}, onError: (Object _) {}));
    if (_closed || request.uri.path != uri.path) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
      response.headers.set('Allow', 'GET, HEAD');
      await response.close();
      return;
    }
    if (_requests.length >= 16) {
      response.statusCode = HttpStatus.serviceUnavailable;
      await response.close();
      return;
    }
    final cancellation = Cancellation();
    _requests.add(cancellation);
    // detachSocket completes the HttpResponse itself; body cancellation is
    // tracked through the detached socket, not this completion signal.
    Socket? socket;
    final id = ++requestCount;
    try {
      response.headers.set('Accept-Ranges', 'bytes');
      response.headers.set('Cache-Control', 'no-store');
      final extension = source.name.toLowerCase().split('.').last;
      response.headers.contentType = switch (extension) {
        'mp4' || 'm4v' => ContentType('video', 'mp4'),
        'mkv' => ContentType('video', 'x-matroska'),
        'webm' => ContentType('video', 'webm'),
        'mov' => ContentType('video', 'quicktime'),
        'avi' => ContentType('video', 'x-msvideo'),
        'ts' => ContentType('video', 'mp2t'),
        _ => ContentType.binary,
      };
      // Range applies only to GET, per HTTP semantics.
      final range = request.method == 'HEAD'
          ? null
          : ByteRange.parse(
              request.headers.value(HttpHeaders.rangeHeader),
              source.length,
            );
      final start = range?.start ?? 0;
      final end = range?.end ?? source.length - 1;
      response.contentLength = range?.length ?? source.length;
      if (range != null) {
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          'Content-Range',
          'bytes $start-$end/${source.length}',
        );
      }
      onEvent?.call({
        'event': 'request',
        'id': id,
        'method': request.method,
        'range': request.headers.value(HttpHeaders.rangeHeader),
        'status': response.statusCode,
        'start': start,
        'end': end,
      });
      if (request.method == 'GET') {
        // HttpResponse.done does not signal a disconnect while no body bytes
        // are available. Own the socket stream to cancel that wait on EOF.
        // Dart still serializes all headers; the advertised body length below
        // is delivered exactly, and each response closes its connection.
        response.persistentConnection = false;
        socket = await response.detachSocket();
        unawaited(socket.done.then((_) {}, onError: (Object _) {}));
        _sockets[cancellation] = socket;
        socket.listen(
          (_) {},
          onDone: cancellation.cancel,
          onError: (Object _) => cancellation.cancel(),
          cancelOnError: true,
        );
        var pendingBytes = 0;
        for (var offset = start; offset <= end;) {
          final count = min(64 * 1024, end - offset + 1);
          final bytes = await source.read(offset, count, cancellation);
          cancellation.check();
          if (bytes.length != count) throw StateError('Short byte-source read');
          socket.add(bytes);
          pendingBytes += count;
          // Send the first chunk promptly; subsequent flushes have bounded
          // backpressure without a round trip to the sink for every read.
          if (offset == start ||
              pendingBytes >= 256 * 1024 ||
              offset + count > end) {
            await cancellation.wait(socket.flush());
            servedBytes += pendingBytes;
            pendingBytes = 0;
          }
          offset += count;
        }
      }
      if (socket == null) {
        await response.close();
      } else {
        await socket.close();
      }
      onEvent?.call({'event': 'request-complete', 'id': id});
    } on UnsatisfiableRange {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set('Content-Range', 'bytes */${source.length}');
      response.contentLength = 0;
      await response.close();
    } catch (error) {
      onEvent?.call({'event': 'request-ended', 'id': id, 'reason': '$error'});
      // Once body headers have been sent, abort instead of claiming false EOF.
      try {
        final connection =
            socket ?? await response.detachSocket(writeHeaders: false);
        connection.destroy();
      } catch (_) {
        // Already disconnected/closed.
      }
    } finally {
      cancellation.cancel();
      _requests.remove(cancellation);
      _sockets.remove(cancellation);
      socket?.destroy();
      source.release(cancellation);
    }
  }

  void cancelReads() {
    for (final request in _requests.toList()) {
      request.cancel();
      _sockets[request]?.destroy();
      source.release(request);
    }
  }

  Future<void> close() async {
    _closed = true;
    cancelReads();
    await _server?.close(force: true);
  }
}
