import 'dart:async';
import 'dart:io';

import 'client.dart';
import 'file_response.dart' show parseRange, unsatisfiable;

/// Retries a broken peer read from the first byte not yet forwarded. A file
/// version/hash remains bound by [headers]; range totals are checked on resume.
class ResumableMediaRelay {
  const ResumableMediaRelay({
    required this.open,
    this.budget = const Duration(seconds: 10),
    this.idleTimeout = const Duration(seconds: 5),
    this.retryDelay = const Duration(milliseconds: 500),
  });
  final Future<HttpClientResponse> Function(Map<String, String>, PeerRequest)
  open;
  final Duration budget, idleTimeout, retryDelay;

  Future<void> send(
    HttpRequest request,
    Map<String, String> headers,
    PeerRequest cancelled,
  ) async {
    var sent = 0, start = 0, end = -1, total = -1;
    var begun = false;
    Stopwatch? outage;
    var failures = 0;
    while (!cancelled.isCancelled) {
      final attempt = PeerRequest();
      try {
        final remaining = outage == null
            ? idleTimeout
            : budget - outage!.elapsed;
        if (remaining <= Duration.zero) {
          throw TimeoutException('Peer reconnect deadline reached');
        }
        final timeout = remaining < idleTimeout ? remaining : idleTimeout;
        final response = await cancelled.wait(
          open({
            ...headers,
            if (begun) HttpHeaders.rangeHeader: 'bytes=${start + sent}-$end',
          }, attempt).timeout(timeout),
        );
        if (response.statusCode >= 400) {
          // Identity, version and permission refusals are not transient outages.
          if (begun) {
            throw PeerException(
              'Peer source changed',
              status: response.statusCode,
            );
          }
          request.response.statusCode = response.statusCode;
          request.response.contentLength = response.contentLength;
          await cancelled.wait(request.response.addStream(response));
          attempt.complete();
          await request.response.close();
          return;
        }
        final span = _span(response);
        if (!begun) {
          final expected = request.method == 'HEAD'
              ? null
              : parseRange(headers[HttpHeaders.rangeHeader], span.total);
          if (expected != null &&
              expected != unsatisfiable &&
              (response.statusCode != 206 ||
                  expected.start != span.start ||
                  expected.end != span.end)) {
            throw const PeerException(
              'Peer returned the wrong initial range',
              status: 502,
            );
          }
          start = span.start;
          end = span.end;
          total = span.total;
          begun = true;
          request.response.statusCode = response.statusCode;
          request.response.contentLength = response.contentLength;
          for (final name in [
            HttpHeaders.contentTypeHeader,
            HttpHeaders.contentRangeHeader,
            HttpHeaders.acceptRangesHeader,
            HttpHeaders.etagHeader,
          ]) {
            if (response.headers.value(name) case final value?) {
              request.response.headers.set(name, value);
            }
          }
        } else if (response.statusCode != 206 ||
            span.start != start + sent ||
            span.end != end ||
            span.total != total) {
          throw const PeerException(
            'Peer returned a different byte range',
            status: 412,
          );
        }
        Object? readError;
        Stream<List<int>> chunks() async* {
          try {
            await for (final chunk in response.timeout(timeout)) {
              sent += chunk.length;
              if (chunk.isNotEmpty) {
                outage = null;
                failures = 0;
              }
              yield chunk;
            }
          } catch (error) {
            readError = error;
          }
        }

        await cancelled.wait(request.response.addStream(chunks()));
        if (readError != null) throw readError!;
        if (request.method != 'HEAD' && sent != end - start + 1) {
          throw const HttpException(
            'Peer read ended before the requested range',
          );
        }
        attempt.complete();
        await request.response.close();
        return;
      } catch (error) {
        attempt.cancel();
        if (cancelled.isCancelled ||
            (error is PeerException && error.status != null)) {
          rethrow;
        }
        outage ??= Stopwatch()..start();
        if (outage!.elapsed >= budget) rethrow;
        final delay = retryDelay * (1 << failures.clamp(0, 3));
        failures++;
        final left = budget - outage!.elapsed;
        await cancelled.wait(Future<void>.delayed(delay < left ? delay : left));
      } finally {
        attempt.cancel();
      }
    }
  }
}

({int start, int end, int total}) _span(HttpClientResponse response) {
  final range = response.headers.value(HttpHeaders.contentRangeHeader);
  if (response.statusCode == 206 && range != null) {
    final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(range);
    if (match != null) {
      final start = int.parse(match[1]!),
          end = int.parse(match[2]!),
          total = int.parse(match[3]!);
      if (start <= end &&
          end < total &&
          response.contentLength == end - start + 1) {
        return (start: start, end: end, total: total);
      }
    }
  } else if (response.statusCode == 200 && response.contentLength >= 0) {
    return (
      start: 0,
      end: response.contentLength - 1,
      total: response.contentLength,
    );
  }
  throw const PeerException('Invalid peer media range', status: 502);
}
