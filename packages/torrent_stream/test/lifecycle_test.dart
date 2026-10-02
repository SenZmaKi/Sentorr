import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:test/test.dart';
import 'package:torrent_stream/torrent_stream.dart';

import 'engine_support.dart';
import 'package:torrent_stream/src/native_runtime.dart';

void main() {
  test(
    'independent sessions share native ownership; closing one preserves the other',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'torrent-stream-multiple-',
      );
      final input = await File(
        '${root.path}/original.bin',
      ).writeAsBytes(Uint8List(262267));
      final source = TorrentSource.metadata(
        createTorrentData(sourcePath: input.path, pieceSize: 128 * 1024),
      );
      final cache = await Directory('${root.path}/cache').create();
      final config = TorrentStreamConfig(
        cacheDirectory: cache.path,
        prepareContainer: false,
      );
      final engine = loopbackEngine();
      final first = TorrentStreamSession(engine: engine, config: config),
          second = TorrentStreamSession(engine: engine, config: config);
      final client = HttpClient();
      try {
        final files = await Future.wait([
          first.open(source),
          second.open(source),
        ]);
        final streams = await Future.wait([
          first.prepareFile(files[0].single.index),
          second.prepareFile(files[1].single.index),
        ]);
        expect(streams[0].uri, isNot(streams[1].uri));
        await first.close();
        final request = await client.openUrl('HEAD', streams[1].uri);
        final response = await request.close();
        expect(response.statusCode, 200);
        expect(response.contentLength, 262267);
        await response.drain<void>();
        expect(second.state.phase, TorrentStreamPhase.serving);
        await second.prepareSeek();
        await second.close();
        expect(await cache.list().length, 0);
        expect(await input.exists(), true);
      } finally {
        client.close(force: true);
        await first.close();
        await second.close();
        await engine.close();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'close interrupts unavailable container preparation and releases all owned bytes',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'torrent-stream-preparing-',
      );
      final input = await File(
        '${root.path}/original.bin',
      ).writeAsBytes(Uint8List(262267));
      final data = createTorrentData(
        sourcePath: input.path,
        pieceSize: 128 * 1024,
      );
      final cache = await Directory('${root.path}/cache').create();
      final engine = loopbackEngine();
      final session = TorrentStreamSession(
        engine: engine,
        config: TorrentStreamConfig(cacheDirectory: cache.path),
      );
      try {
        final files = await session.open(TorrentSource.metadata(data));
        final pending = session.prepareFile(files.single.index);
        final cancelled = expectLater(
          pending,
          throwsA(
            isA<TorrentStreamException>().having(
              (e) => e.code,
              'code',
              TorrentStreamErrorCode.cancelled,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final watch = Stopwatch()..start();
        await session.close();
        await cancelled;
        expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
        expect(await cache.list().length, 0);
        expect(await input.exists(), true);
      } finally {
        await session.close();
        await engine.close();
        await root.delete(recursive: true);
      }
    },
  );
  test('a paused state observer cannot block close', () async {
    final root = await Directory.systemTemp.createTemp(
      'torrent-stream-observer-',
    );
    final engine = loopbackEngine();
    final session = TorrentStreamSession(
      engine: engine,
      config: TorrentStreamConfig(cacheDirectory: root.path),
    );
    final subscription = session.states.listen((_) {});
    subscription.pause();
    try {
      await session.close().timeout(const Duration(seconds: 3));
      expect(session.state.phase, TorrentStreamPhase.closed);
    } finally {
      await subscription.cancel();
      await engine.close();
      await root.delete(recursive: true);
    }
  });
  test(
    'unexpected worker exit fails promptly and close does not wait for a dead port',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'torrent-stream-worker-exit-',
      );
      final engine = loopbackEngine();
      final session = TorrentStreamSession(
        engine: engine,
        config: TorrentStreamConfig(cacheDirectory: root.path),
      );
      final failed = Completer<TorrentStreamException>();
      void observe(TorrentStreamException error) {
        if (!failed.isCompleted) failed.complete(error);
      }

      final runtime = NativeRuntime.acquire(observe);
      try {
        // Fault injection at the private worker seam, without exposing a public
        // test-only kill method. Malformed worker input triggers an isolate exit.
        final port = await runtime.ready;
        port.send(<String, Object?>{});
        final error = await failed.future.timeout(const Duration(seconds: 3));
        expect(error.code, TorrentStreamErrorCode.workerExited);
        expect(session.state.phase, TorrentStreamPhase.failed);
        await expectLater(
          session.close().timeout(const Duration(seconds: 3)),
          throwsA(
            isA<TorrentStreamException>().having(
              (e) => e.code,
              'code',
              TorrentStreamErrorCode.workerExited,
            ),
          ),
        );
        expect(session.state.phase, TorrentStreamPhase.closed);
      } finally {
        runtime.release(observe);
        await root.delete(recursive: true);
      }
    },
  );
}
