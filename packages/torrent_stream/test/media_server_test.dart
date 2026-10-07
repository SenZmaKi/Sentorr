import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/byte_source.dart';
import 'package:torrent_stream/src/engine/cancellation.dart';
import 'package:torrent_stream/src/engine/media_server.dart';

class TestBytes implements ByteSource {
  TestBytes({int length = 200123})
    : data = Uint8List.fromList(List.generate(length, (i) => i % 251));
  final Uint8List data;
  int? blockAfterReads;
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
    if (blocked || (blockAfterReads != null && reads > blockAfterReads!)) {
      await cancellation.wait(Completer<void>().future);
    }
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
  test('batched flushes preserve a full multi-batch response', () async {
    await server.close();
    source = TestBytes(length: 1024123);
    server = MediaServer(source);
    await server.start();
    final (_, data) = await get();
    expect(data, source.data);
    expect(server.servedBytes, source.length);
  });

  test(
    'first chunk arrives without waiting for the next missing piece',
    () async {
      source.blockAfterReads = 1;
      final response = await (await client.getUrl(server.uri)).close();
      final arrived = Completer<void>();
      final received = BytesBuilder();
      final subscription = response.listen((data) {
        received.add(data);
        if (received.length >= 64 * 1024 && !arrived.isCompleted) {
          arrived.complete();
        }
      }, onError: (Object _) {});
      await arrived.future.timeout(const Duration(seconds: 2));
      expect(received.toBytes(), source.data.sublist(0, 64 * 1024));
      server.cancelReads();
      await subscription.cancel();
    },
  );
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

  test(
    'connection reset during a body write leaves the server usable',
    () async {
      await server.close();
      source = TestBytes(length: 16 * 1024 * 1024);
      server = MediaServer(source);
      await server.start();
      final socket = await Socket.connect(server.uri.host, server.uri.port);
      final arrived = Completer<void>();
      socket.listen((_) {
        if (!arrived.isCompleted) arrived.complete();
      }, onError: (Object _) {});
      // Abort with RST, as a player replacing its current HTTP stream can do.
      final linger = Int32List.fromList([1, 0]);
      socket.setRawOption(
        RawSocketOption(
          RawSocketOption.levelSocket,
          Platform.isMacOS ? 0x0080 : 13,
          linger.buffer.asUint8List(),
        ),
      );
      socket.write(
        'GET ${server.uri.path} HTTP/1.1\r\nHost: ${server.uri.host}\r\n\r\n',
      );
      await socket.flush();
      await arrived.future.timeout(const Duration(seconds: 2));
      socket.destroy();
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (source.releases == 0 && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(source.releases, greaterThan(0));
      expect((await get(range: 'bytes=0-99')).$2, source.data.sublist(0, 100));
    },
  );
}
