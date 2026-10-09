import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/cache_ranges.dart';
import 'package:sentorr/player/stream/stream_status.dart';
import 'package:torrent_stream/torrent_stream.dart';

const raw = '{"seekable-ranges":[{"start":10,"end":20},{"start":70,"end":90}]}';
const active = StreamStatus(stage: StreamStage.streaming);

void main() {
  test('native cache ranges preserve gaps, clamp and merge overlap', () {
    expect(parseCacheRanges(raw, const Duration(seconds: 100)), [
      (start: 0.1, end: 0.2),
      (start: 0.7, end: 0.9),
    ]);
    expect(
      parseCacheRanges(
        '{"seekable-ranges":[{"start":80,"end":120},'
        '{"start":-5,"end":20},{"start":10,"end":30},'
        '{"start":40,"end":35},{"start":"bad","end":50}]}',
        const Duration(seconds: 100),
      ),
      [(start: 0.0, end: 0.3), (start: 0.8, end: 1.0)],
    );
    for (final value in ['', 'unavailable', '{}', '[]']) {
      expect(parseCacheRanges(value, const Duration(seconds: 100)), isEmpty);
    }
    expect(parseCacheRanges(raw, Duration.zero), isEmpty);
  });

  test(
    'cache eviction replaces coverage and missing properties clear it',
    () async {
      final status = ValueNotifier<StreamStatus?>(active);
      var response = raw;
      final cache = PlaybackCacheRanges(
        status: status,
        read: () async => response,
        duration: () => const Duration(seconds: 100),
      );
      await cache.sample();
      expect(cache.value.length, 2);
      response = '{"seekable-ranges":[{"start":70,"end":80}]}';
      await cache.sample();
      expect(cache.value, [(start: 0.7, end: 0.8)]);
      response = '';
      await cache.sample();
      expect(cache.value, isEmpty);
      cache.dispose();
      status.dispose();
    },
  );

  test(
    'resolved empty index wins over cache and stops native sampling',
    () async {
      final status = ValueNotifier<StreamStatus?>(active);
      var reads = 0;
      final cache = PlaybackCacheRanges(
        status: status,
        read: () async {
          reads++;
          return raw;
        },
        duration: () => const Duration(seconds: 100),
      );
      await cache.sample();
      status.value = const StreamStatus(
        stage: StreamStage.streaming,
        transfer: TorrentStreamState(mediaDuration: 100),
      );
      expect(status.value!.hasDownloadedTimeline, isTrue);
      expect(status.value!.downloadedSpans, isEmpty);
      expect(cache.value, isEmpty);
      await cache.sample();
      expect(reads, 1);
      cache.dispose();
      status.dispose();
    },
  );

  test(
    'seek, source replacement and disposal discard in-flight samples',
    () async {
      for (final action in ['seek', 'source', 'dispose']) {
        final pending = Completer<String>();
        final status = ValueNotifier<StreamStatus?>(active);
        final cache = PlaybackCacheRanges(
          status: status,
          read: () => pending.future,
          duration: () => const Duration(seconds: 100),
        );
        final sampling = cache.sample();
        if (action == 'seek') cache.invalidate();
        if (action == 'source') {
          status.value = const StreamStatus(stage: StreamStage.preparing);
        }
        if (action == 'dispose') cache.dispose();
        pending.complete(raw);
        await sampling;
        expect(cache.value, isEmpty);
        if (action != 'dispose') cache.dispose();
        status.dispose();
      }
    },
  );
}
