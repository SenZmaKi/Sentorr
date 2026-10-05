import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/queue_builder.dart';
import 'package:sentorr/player/session.dart';

import '../support/fake_imdb.dart';
import '../support/fake_playback.dart';

class _SlowBuilder extends QueueBuilder {
  _SlowBuilder()
    : super(FakeImdbRepository(), (_) async => throw StateError('unused'));
  final pending = <Completer<PlayQueue>>[];
  @override
  Future<PlayQueue> extend(PlayQueue queue, CancelToken cancel) {
    final next = Completer<PlayQueue>();
    pending.add(next);
    return next.future;
  }
}

void main() {
  final series = ImdbTitle(id: 'tt1', title: 'Series');
  final items = List.generate(
    4,
    (n) => PlaybackItem(
      title: ImdbTitle(id: 'tt${n + 2}', title: 'Episode $n'),
      series: series,
      season: n < 2 ? 1 : 2,
      episode: n % 2 + 1,
    ),
  );
  late _SlowBuilder builder;
  late ProviderContainer container;
  late PlayerSessionNotifier session;
  late PlayQueue initial;
  setUp(() {
    builder = _SlowBuilder();
    container = ProviderContainer(
      overrides: [queueBuilderProvider.overrideWithValue(builder)],
    );
    session = container.read(playerSessionProvider.notifier);
    initial = PlayQueue(
      items: items.take(2).toList(),
      index: 1,
      kind: QueueKind.episodes,
      nextSeason: 2,
    );
    session.play(PlayTitle(series), queue: initial);
  });
  tearDown(() => container.dispose());

  test('repeated Next shares one extension and advances once', () async {
    session.next();
    session.next();
    expect(builder.pending, hasLength(1));
    builder.pending.single.complete(initial.extended(items.skip(2).toList()));
    await settlePlayback();
    expect(session.queue!.current.id, items[2].id);
  });

  test(
    'Previous cancels pending advancement while retaining fetched season',
    () async {
      session.next();
      session.previous();
      builder.pending.single.complete(initial.extended(items.skip(2).toList()));
      await settlePlayback();
      expect(session.queue!.current.id, items[0].id);
      expect(session.queue!.items, hasLength(4));
    },
  );

  test(
    'Next during prefetch advances when that same extension finishes',
    () async {
      session.previous();
      session.next(); // entering last episode prefetches
      expect(builder.pending, hasLength(1));
      session.next();
      expect(builder.pending, hasLength(1));
      builder.pending.single.complete(initial.extended(items.skip(2).toList()));
      await settlePlayback();
      expect(session.queue!.current.id, items[2].id);
    },
  );

  test(
    'an extension finishing after a new session cannot change its queue',
    () async {
      session.next();
      session.play(
        PlayTitle(items[0].title),
        queue: PlayQueue(
          items: [items[0]],
          index: 0,
          kind: QueueKind.recommendations,
        ),
      );
      builder.pending.single.complete(initial.extended(items.skip(2).toList()));
      await settlePlayback();
      expect(session.queue!.items, hasLength(1));
    },
  );
}
