import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/sync/client.dart';
import 'package:sentorr/sync/media_relay.dart';

void main() {
  test('broken mid-range resumes at the next byte without duplicates', () async {
    final bytes = List.generate(20000, (i) => i % 251);
    final ranges = <String>[];
    final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    source.listen((r) async {
      final range = r.headers.value(HttpHeaders.rangeHeader)!;
      ranges.add(range);
      final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
      final start = int.parse(match[1]!), end = int.parse(match[2]!);
      if (ranges.length == 1) {
        final socket = await r.response.detachSocket(writeHeaders: false);
        socket.write(
          'HTTP/1.1 206 Partial Content\r\nContent-Length: ${end - start + 1}\r\nContent-Range: bytes $start-$end/${bytes.length}\r\nConnection: close\r\n\r\n',
        );
        socket.add(bytes.sublist(start, start + 1024));
        await socket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        socket.destroy();
      } else {
        r.response
          ..statusCode = 206
          ..contentLength = end - start + 1;
        r.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/${bytes.length}',
        );
        r.response.add(bytes.sublist(start, end + 1));
        await r.response.close();
      }
    });
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    proxy.listen((r) async {
      final cancelled = PeerRequest();
      try {
        await ResumableMediaRelay(
          retryDelay: const Duration(milliseconds: 5),
          open: (headers, attempt) async {
            final http = HttpClient();
            attempt.bind(http);
            final request = await http.getUrl(
              Uri.parse('http://127.0.0.1:${source.port}/'),
            );
            headers.forEach(request.headers.set);
            return request.close();
          },
        ).send(r, {HttpHeaders.rangeHeader: 'bytes=100-15000'}, cancelled);
      } finally {
        cancelled.cancel();
      }
    });
    final http = HttpClient();
    try {
      final response = await (await http.getUrl(
        Uri.parse('http://127.0.0.1:${proxy.port}/'),
      )).close();
      expect(response.statusCode, 206);
      final received = await response.fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      expect(received, bytes.sublist(100, 15001));
      expect(ranges, ['bytes=100-15000', 'bytes=1124-15000']);
    } finally {
      http.close(force: true);
      await proxy.close(force: true);
      await source.close(force: true);
    }
  });

  test('a peer cannot substitute a different initial byte range', () async {
    final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    source.listen((r) async {
      r.response
        ..statusCode = 206
        ..contentLength = 3;
      r.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-2/100');
      r.response.add([1, 2, 3]);
      await r.response.close();
    });
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final refused = Completer<Object>();
    proxy.listen((r) async {
      final cancelled = PeerRequest();
      try {
        await ResumableMediaRelay(
          open: (headers, attempt) async {
            final client = HttpClient();
            attempt.bind(client);
            final request = await client.getUrl(
              Uri.parse('http://127.0.0.1:${source.port}/'),
            );
            headers.forEach(request.headers.set);
            return request.close();
          },
        ).send(r, {HttpHeaders.rangeHeader: 'bytes=10-12'}, cancelled);
      } catch (error) {
        refused.complete(error);
        r.response.statusCode = 502;
        await r.response.close();
      } finally {
        cancelled.cancel();
      }
    });
    final http = HttpClient();
    try {
      final response = await (await http.getUrl(
        Uri.parse('http://127.0.0.1:${proxy.port}/'),
      )).close();
      expect(response.statusCode, 502);
      await response.drain<void>();
      expect(await refused.future, isA<PeerException>());
    } finally {
      http.close(force: true);
      await proxy.close(force: true);
      await source.close(force: true);
    }
  });

  test('unreachable source stops retrying within its budget', () async {
    final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final stopped = Completer<void>();
    var attempts = 0;
    proxy.listen((r) async {
      final cancelled = PeerRequest();
      try {
        await ResumableMediaRelay(
          budget: const Duration(milliseconds: 80),
          retryDelay: const Duration(milliseconds: 10),
          open: (_, _) async {
            attempts++;
            throw const SocketException('offline');
          },
        ).send(r, {}, cancelled);
      } catch (_) {
        r.response.statusCode = 502;
        await r.response.close();
        stopped.complete();
      } finally {
        cancelled.cancel();
      }
    });
    final http = HttpClient();
    try {
      final response = await (await http.getUrl(
        Uri.parse('http://127.0.0.1:${proxy.port}/'),
      )).close();
      expect(response.statusCode, 502);
      await stopped.future.timeout(const Duration(seconds: 2));
      expect(attempts, greaterThan(1));
      expect(attempts, lessThan(10));
    } finally {
      http.close(force: true);
      await proxy.close(force: true);
    }
  });
}
