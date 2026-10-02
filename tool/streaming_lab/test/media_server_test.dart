import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:streaming_lab/engine/byte_source.dart';
import 'package:streaming_lab/engine/cancellation.dart';
import 'package:streaming_lab/engine/media_server.dart';

class TestBytes implements ByteSource {
  final data = Uint8List.fromList(List.generate(200123, (i) => i % 251));
  bool blocked = false;
  int reads = 0;
  int releases = 0;
  @override
  String get name => 'fixture.mp4';
  @override
  int get length => data.length;
  @override
  Future<Uint8List> read(
    int offset,
    int count,
    Cancellation cancellation,
  ) async {
    reads++;
    if (blocked) await cancellation.wait(Completer<void>().future);
    return data.sublist(offset, offset + count);
  }

  @override
  void release(Cancellation cancellation) {
    releases++;
  }
}

void main() {
  late TestBytes source;
  late MediaServer server;
  late HttpClient client;
  setUp(() async {
    source = TestBytes();
    server = MediaServer(source);
    await server.start();
    client = HttpClient();
  });
  tearDown(() async {
    client.close(force: true);
    await server.close();
  });
  Future<(HttpClientResponse, List<int>)> get({
    String? range,
    String method = 'GET',
  }) async {
    final request = await client.openUrl(method, server.uri);
    if (range != null) request.headers.set('Range', range);
    final response = await request.close();
    final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
    return (response, bytes);
  }

  test('full GET and cross-chunk range are exact', () async {
    final (full, data) = await get();
    expect(full.statusCode, 200);
    expect(full.contentLength, source.length);
    expect(data, source.data);
    final (partial, bytes) = await get(range: 'bytes=65530-131090');
    expect(partial.statusCode, 206);
    expect(
      partial.headers.value('Content-Range'),
      'bytes 65530-131090/${source.length}',
    );
    expect(bytes, source.data.sublist(65530, 131091));
  });
  test('suffix, open-ended and clipped ranges', () async {
    expect(
      (await get(range: 'bytes=-19')).$2,
      source.data.sublist(source.length - 19),
    );
    expect((await get(range: 'bytes=200110-')).$2, source.data.sublist(200110));
    expect(
      (await get(range: 'bytes=200110-999999')).$2,
      source.data.sublist(200110),
    );
  });
  test('HEAD does not read bytes and ignores Range', () async {
    final (response, bytes) = await get(method: 'HEAD', range: 'bytes=5-10');
    expect(response.statusCode, 200);
    expect(response.contentLength, source.length);
    expect(bytes, isEmpty);
    expect(source.reads, 0);
  });
  test('416 is reserved for valid unsatisfiable ranges', () async {
    final (response, data) = await get(range: 'bytes=${source.length}-');
    expect(response.statusCode, 416);
    expect(response.headers.value('Content-Range'), 'bytes */${source.length}');
    expect(data, isEmpty);
    expect((await get(range: 'bytes=9-3')).$1.statusCode, 200);
    expect((await get(range: 'bytes=1-2,5-6')).$1.statusCode, 200);
  });
  test('unknown URL and unsupported method are rejected', () async {
    final request = await client.getUrl(server.uri.replace(path: '/other'));
    final response = await request.close();
    expect(response.statusCode, 404);
    await response.drain<void>();
    expect((await get(method: 'POST')).$1.statusCode, 405);
  });
  test('seek cancellation interrupts a blocked byte read', () async {
    source.blocked = true;
    final pending = get(range: 'bytes=0-99');
    final failed = expectLater(pending, throwsA(isA<Exception>()));
    while (source.reads == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    server.cancelReads();
    await failed.timeout(const Duration(seconds: 2));
    expect(source.releases, greaterThan(0));
  });
  test('client disconnect releases a reader waiting on missing bytes', () async {
    source.blocked = true;
    final socket = await Socket.connect(server.uri.host, server.uri.port);
    socket.write(
      'GET ${server.uri.path} HTTP/1.1\r\nHost: ${server.uri.host}\r\nRange: bytes=0-99\r\n\r\n',
    );
    await socket.flush();
    while (source.reads == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    socket.destroy();
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (source.releases == 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(source.releases, greaterThan(0));
  });
}
