import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/next_warmup.dart';
import 'package:sentorr/player/stream/prepared_stream.dart';
import 'package:sentorr/torrents/resolution_models.dart';

import '../support/fake_torrents.dart';

class _Preparation extends PreparedStreams {
  _Preparation() : super(create: (_, _) => throw StateError('unused'));
  int calls = 0;
  @override
  void start(
    PlaybackItem item,
    TorrentCandidate candidate, {
    Duration lifetime = const Duration(minutes: 1),
  }) {
    calls++;
  }
}

void main() {
  final items = [
    for (var n = 1; n <= 3; n++)
      PlaybackItem(
        title: ImdbTitle(id: 'tt$n', title: 'Episode $n'),
      ),
  ];
  final queue = PlayQueue(items: items, index: 0, kind: QueueKind.episodes);
  final candidate = TorrentCandidate(
    release: fakeRelease(1),
    score: 1,
    qualityScore: 1,
    availabilityScore: 1,
    sizeScore: 1,
    requiresFileSelection: false,
  );
  test(
    'only warms a playing next episode near the end, once per queue target',
    () async {
      final prepared = _Preparation();
      var searches = 0;
      final warmup = NextTorrentWarmup(
        prepared: prepared,
        available: (_) => false,
        find: (_, _) async {
          searches++;
          return candidate;
        },
      );
      warmup.update(
        queue,
        const Duration(seconds: 100),
        const Duration(seconds: 300),
        playing: true,
      );
      warmup.update(
        queue,
        const Duration(seconds: 220),
        const Duration(seconds: 300),
        playing: false,
      );
      expect(searches, 0);
      warmup.update(
        queue,
        const Duration(seconds: 220),
        const Duration(seconds: 300),
        playing: true,
      );
      await Future<void>.delayed(Duration.zero);
      warmup.update(
        queue,
        const Duration(seconds: 230),
        const Duration(seconds: 300),
        playing: true,
      );
      expect(searches, 1);
      expect(prepared.calls, 1);
      warmup.dispose();
    },
  );
  test(
    'queue replacement and disposal suppress late search completion',
    () async {
      for (final dispose in [false, true]) {
        final prepared = _Preparation();
        final gate = Completer<TorrentCandidate?>();
        final warmup = NextTorrentWarmup(
          prepared: prepared,
          available: (_) => false,
          find: (_, _) => gate.future,
        );
        warmup.update(
          queue,
          const Duration(seconds: 220),
          const Duration(seconds: 300),
          playing: true,
        );
        if (dispose) {
          warmup.dispose();
        } else {
          warmup.update(null, Duration.zero, Duration.zero, playing: false);
        }
        gate.complete(candidate);
        await Future<void>.delayed(Duration.zero);
        expect(prepared.calls, 0);
        if (!dispose) warmup.dispose();
      }
    },
  );
  test(
    'existing offline/peer sources and movie recommendations are not warmed',
    () {
      final prepared = _Preparation();
      var searches = 0;
      final warmup = NextTorrentWarmup(
        prepared: prepared,
        available: (_) => true,
        find: (_, _) async {
          searches++;
          return candidate;
        },
      );
      warmup.update(
        queue,
        const Duration(seconds: 220),
        const Duration(seconds: 300),
        playing: true,
      );
      warmup.update(
        PlayQueue(items: items, index: 0, kind: QueueKind.recommendations),
        const Duration(seconds: 220),
        const Duration(seconds: 300),
        playing: true,
      );
      expect(searches, 0);
      warmup.dispose();
    },
  );
}
