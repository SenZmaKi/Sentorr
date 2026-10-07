import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/stream/parked_stream.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../support/fake_torrents.dart';

class _Session implements TorrentStreamSession {
  int closes = 0;
  bool fails = false;
  Completer<void>? closing;
  @override
  Future<void> close() async {
    closes++;
    await closing?.future;
    if (fails) throw StateError('close failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ParkedStream _stream(String item, _Session session) => ParkedStream(
  itemId: item,
  candidate: TorrentCandidate(
    release: fakeRelease(1),
    score: 1,
    qualityScore: 1,
    availabilityScore: 1,
    sizeScore: 1,
    requiresFileSelection: false,
  ),
  session: session,
  stream: TorrentStream(
    uri: Uri.parse('http://127.0.0.1/video'),
    file: const TorrentStreamFile(
      index: 0,
      path: 'video.mkv',
      length: 100,
      isPadFile: false,
    ),
  ),
);

void main() {
  test('shutdown drains previously queued and held stream cleanup', () async {
    final held = ParkedStreams();
    final first = _Session()..closing = Completer<void>();
    final second = _Session();
    await held.park(_stream('a', first));
    expect(held.take('other'), null);
    await held.park(_stream('b', second));

    var finished = false;
    final shutdown = held.dispose().then((_) => finished = true);
    await Future<void>.delayed(Duration.zero);
    expect(first.closes, 1);
    expect(second.closes, 0);
    expect(finished, false);

    first.closing!.complete();
    await shutdown;
    expect(second.closes, 1);
    await held.dispose();
    expect(first.closes, 1);
    expect(second.closes, 1);
  });

  testWidgets('a parked stream expires after five minutes', (tester) async {
    final held = ParkedStreams();
    final session = _Session();
    await held.park(_stream('a', session));
    await tester.pump(const Duration(minutes: 4, seconds: 59));
    expect(session.closes, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(session.closes, 1);
    expect(held.take('a'), null);
    await held.dispose();
  });

  testWidgets(
    'taking a stream cancels expiry without closing its active session',
    (tester) async {
      final held = ParkedStreams();
      final session = _Session(), stream = _stream('a', session);
      await held.park(stream);
      expect(held.take('a'), same(stream));
      await tester.pump(const Duration(minutes: 6));
      await held.dispose();
      expect(session.closes, 0);
    },
  );

  testWidgets(
    'replacement gets a fresh timeout even when older cleanup fails',
    (tester) async {
      final held = ParkedStreams();
      final first = _Session()..fails = true;
      final second = _Session();
      await held.park(_stream('a', first));
      await tester.pump(const Duration(minutes: 4));
      await held.park(_stream('b', second));
      expect(first.closes, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(second.closes, 0);
      await tester.pump(const Duration(minutes: 4));
      expect(second.closes, 1);
      await held.dispose();
    },
  );

  test('disposal closes held and subsequently parked sessions', () async {
    final held = ParkedStreams();
    final first = _Session(), second = _Session();
    await held.park(_stream('a', first));
    await held.dispose();
    await held.park(_stream('b', second));
    expect(first.closes, 1);
    expect(second.closes, 1);
  });
}
