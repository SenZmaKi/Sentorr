import 'dart:io';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/cancellation.dart';
import 'package:torrent_stream/src/engine/diagnosis.dart';
import 'package:torrent_stream/src/engine/media_server.dart';
import 'package:torrent_stream/src/engine/piece_scheduler.dart';
import 'package:torrent_stream/src/engine/read_waits.dart';
import 'package:torrent_stream/src/engine/stream_startup.dart';

import 'media_server_test.dart' show TestBytes;
import 'read_support.dart';

PeerInfo peer({
  String client = 'qB',
  int down = 0,
  int flags = 0,
  int source = 0,
}) => PeerInfo(
  ip: '10.0.0.1',
  port: 6881,
  client: client,
  upSpeed: 0,
  downSpeed: down,
  payloadUpSpeed: 0,
  payloadDownSpeed: down,
  totalDownload: down * 10,
  totalUpload: 0,
  flags: flags,
  source: source,
);

void main() {
  test('read waits count each blocked piece once and list stalls', () async {
    final waits = ReadWaits();
    final clock = waits.begin(4);
    expect(identical(waits.begin(4), clock), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      (waits.describe()['pending'] as List).single,
      containsPair('piece', 4),
    );
    waits.end(4, clock);
    waits.end(4, clock);
    final quick = waits.begin(5);
    waits.end(5, quick);
    final described = waits.describe();
    expect(described['waits'], 1);
    expect(described['slowestPiece'], 4);
    expect(described['slowestMs'] as int, greaterThanOrEqualTo(20));
    expect(described['pending'], isEmpty);
  });

  test('startup reports how long the latest start took', () {
    final startup = StreamStartup(1000)..begin(100);
    expect(startup.describe()['starting'], isTrue);
    expect(startup.served(0, 0, 100, Stopwatch()), isTrue);
    final described = startup.describe();
    expect(described['starting'], isFalse);
    expect(described['lastReadyMs'], isNotNull);
  });

  test('scheduler lists live windows and which are background', () {
    final scheduler = PieceScheduler(TestHandle(pieceLength: 1024 * 1024));
    final play = Cancellation(), disk = Cancellation();
    scheduler.demand(play, 10, 30, 4);
    scheduler.demand(disk, 0, 30, 20, urgent: false);
    expect(scheduler.windows, [
      (first: 10, last: 14, urgent: 2, background: false),
      (first: 0, last: 20, urgent: 2, background: true),
    ]);
    play.cancel();
    expect(scheduler.windows, hasLength(1));
  });

  test('media server keeps the latest requests and how they ended', () async {
    final server = MediaServer(TestBytes());
    await server.start();
    final client = HttpClient();
    try {
      for (final range in ['bytes=0-99', 'bytes=500-599']) {
        final request = await client.getUrl(server.uri);
        request.headers.set('Range', range);
        await (await request.close()).drain<void>();
      }
      final recent = server.recent.map((r) => r.describe()).toList();
      expect(recent, hasLength(2));
      expect(recent.last, containsPair('start', 500));
      expect(recent.last, containsPair('servedBytes', 100));
      expect(recent.last, containsPair('outcome', 'complete'));
    } finally {
      client.close(force: true);
      await server.close();
    }
  });

  test('peers are described by role, transport and source', () {
    const seed = 1 << 10, utp = 1 << 17, interesting = 1, remoteChoked = 1 << 3;
    final described = describePeers([
      peer(client: 'fast', down: 900, flags: seed | utp, source: 2),
      peer(client: 'slow', down: 100, source: 1 | 4),
      peer(client: 'stingy', flags: interesting | remoteChoked, source: 1),
      peer(client: 'dialing', flags: 1 << 7),
    ]);
    expect(described['connected'], 3);
    expect(described['connecting'], 1);
    expect(described['seeds'], 1);
    expect(described['utp'], 1);
    expect(described['sendingToUs'], 2);
    expect(described['interestingButChoking'], 1);
    expect(described['bySource'], containsPair('tracker', 2));
    expect(described['bySource'], containsPair('pex', 1));
    final top = (described['top'] as List).cast<Map>();
    expect(top.map((p) => p['client']), ['fast', 'slow', 'stingy']);
    expect(top.first['transport'], 'utp');
    expect(top.first['source'], ['dht']);
    expect(top.first.containsKey('ip'), isFalse);
  });
}
