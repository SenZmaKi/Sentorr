// AOT benchmark of the production engine and HTTP endpoint, without player/UI.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:torrent_stream/torrent_stream.dart';

final cpuClock = DynamicLibrary.process()
    .lookupFunction<Int64 Function(), int Function()>('clock');
void emit(Map<String, Object?> event) => stdout.writeln(jsonEncode(event));

Future<void> main(List<String> args) async {
  final fixture = args[0];
  final pieceBytes = int.parse(args[1]);
  if (args[2] == 'prepare') {
    final metadata = createTorrentData(
      sourcePath: '$fixture/video.bin',
      pieceSize: pieceBytes,
    );
    await File('$fixture/$pieceBytes.torrent').writeAsBytes(metadata);
    return;
  }
  final scenario = args[2];
  final engine = TorrentEngine(
    settings: TorrentEngineSettings(
      transport: TorrentTransport.tcpOnly,
      enableDht: false,
      enableLsd: false,
      enableUpnp: false,
      enableNatPmp: false,
      listenInterfaces: '127.0.0.1:0',
    ),
  );
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final hash = await engine.add(
      TorrentSource.metadata(
        await File('$fixture/$pieceBytes.torrent').readAsBytes(),
      ),
      owner: 'audit',
      directory: fixture,
      storage: TorrentStorage.cached,
    );
    final files = await engine.metadata(hash);
    final file = files.single;
    final timeout = Stopwatch()..start();
    while ((engine.torrent(hash)?.verifiedBytes ?? 0) < file.length) {
      if (timeout.elapsed.inSeconds > 60) {
        throw StateError('Fixture verification timed out');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final stream = await engine.stream(
      hash,
      'audit',
      file.index,
      options: StreamOptions(
        pieceCacheBytes: 0,
        readAheadBytes: 2 * 1024 * 1024,
        prepareContainer: false,
      ),
    );
    Future<int> read(int start, int count) async {
      final request = await client.getUrl(stream.uri);
      request.headers.set(
        HttpHeaders.rangeHeader,
        'bytes=$start-${start + count - 1}',
      );
      final response = await request.close();
      if (response.statusCode != 206) {
        throw StateError('HTTP ${response.statusCode}');
      }
      var consumed = 0;
      await for (final bytes in response) {
        for (var i = 0; i < bytes.length; i++) {
          if (bytes[i] != ((start + consumed + i) % 251)) {
            throw StateError('Byte mismatch');
          }
        }
        consumed += bytes.length;
      }
      if (consumed != count) throw StateError('Short response');
      return consumed;
    }

    // Equal warmup. Baseline includes the retained heap from one native read.
    await read(0, 64 * 1024);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    emit({'event': 'ready', 'pid': pid, 'rss': ProcessInfo.currentRss});
    // External sampler starts before acknowledging measurement readiness.
    await stdin.first;
    final rssStart = ProcessInfo.currentRss;
    var rssPeak = rssStart;
    final sampler = Timer.periodic(const Duration(milliseconds: 5), (_) {
      final rss = ProcessInfo.currentRss;
      if (rss > rssPeak) rssPeak = rss;
    });
    final cpuStart = cpuClock();
    final clock = Stopwatch()..start();
    var total = 0;
    final latencies = <double>[];
    if (scenario == 'sequential') {
      total = await read(64 * 1024, 4 * 1024 * 1024);
    } else if (scenario == 'seeks') {
      for (var i = 0; i < 24; i++) {
        // Fixed, deterministic jumps and unaligned ranges on the same file.
        final start = ((i * 7919 * 1024) + 17) % (file.length - 65536);
        final requestClock = Stopwatch()..start();
        total += await read(start, 64 * 1024);
        latencies.add(requestClock.elapsedMicroseconds / 1000);
      }
    } else {
      throw ArgumentError('Unknown scenario');
    }
    clock.stop();
    final cpuMs = (cpuClock() - cpuStart) / 1000; // POSIX CLOCKS_PER_SEC = 1e6.
    sampler.cancel();
    rssPeak = [rssPeak, ProcessInfo.currentRss].reduce((a, b) => a > b ? a : b);
    latencies.sort();
    emit({
      'event': 'result',
      'pieceBytes': pieceBytes,
      'scenario': scenario,
      'bytes': total,
      'elapsedMs': clock.elapsedMicroseconds / 1000,
      'throughputMiBs':
          total / (1024 * 1024) / (clock.elapsedMicroseconds / 1e6),
      'cpuMs': cpuMs,
      'rssStart': rssStart,
      'rssPeakSampled': rssPeak,
      'seekMedianMs': latencies.isEmpty
          ? null
          : latencies[latencies.length ~/ 2],
      'seekP95Ms': latencies.isEmpty
          ? null
          : latencies[((latencies.length - 1) * .95).ceil()],
      'seekMaxMs': latencies.isEmpty ? null : latencies.last,
      'correctBytes': true,
    });
  } finally {
    client.close(force: true);
    await engine.close();
  }
}
