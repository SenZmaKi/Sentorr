import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/following/models.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/following/snapshot.dart';

import '../support/fake_following.dart';
import '../support/fake_imdb.dart';

final _now = DateTime.now();
final _a = fakeTitle(1, series: true), _b = fakeTitle(2, series: true);
DateTime _ago(int minutes) => _now.subtract(Duration(minutes: minutes));

FollowedSnapshot _snap(
  List<FollowedSeries> series, [
  Map<String, DateTime> removed = const {},
]) => FollowedSnapshot(series, removed);

void main() {
  test('keeps the furthest episode and the latest watch', () {
    final mine = following(_a, episode: 3, progress: .5, watchedAt: _ago(5));
    final theirs = following(_a, episode: 2, progress: 1, watchedAt: _ago(1));
    final merged = _snap([mine]).merge(_snap([theirs])).series.single;
    expect(merged.reached, (season: 1, episode: 3));
    expect(merged.progress, .5);
    expect(merged.watchedAt, _ago(1));
  });

  test('takes the latest notification choices; auto-download stays mine', () {
    final mine = following(
      _a,
      episode: 1,
    ).copyWith(notify: true, notifyAt: _ago(10), autoDownload: true);
    final theirs = following(_a, episode: 1).copyWith(
      notify: false,
      notifyAt: _ago(2),
      notified: 'tt9',
      notifiedAt: _ago(2),
      autoDownload: false,
    );
    final merged = _snap([mine]).merge(_snap([theirs])).series.single;
    expect(merged.notify, false);
    expect(merged.notified, 'tt9');
    expect(merged.autoDownload, true);
    final added = _snap([]).merge(_snap([theirs])).series.single;
    expect(added.autoDownload, isNull);
  });

  test('an unfollow wins over older records, not newer ones', () {
    final watched = following(_a, episode: 1, watchedAt: _ago(10));
    final unfollowed = _snap([], {_a.id: _ago(5)});
    expect(_snap([watched]).merge(unfollowed).series, isEmpty);
    expect(unfollowed.merge(_snap([watched])).series, isEmpty);
    final rewatched = following(_a, episode: 2, watchedAt: _ago(1));
    expect(unfollowed.merge(_snap([rewatched])).series.single.id, _a.id);
  });

  test('merging is order-independent and idempotent', () {
    final x = _snap([
      following(_a, episode: 4, watchedAt: _ago(3)),
      following(_b, episode: 1, progress: .2, watchedAt: _ago(9)),
    ]);
    final y = _snap(
      [following(_b, episode: 2, watchedAt: _ago(1))],
      {_a.id: _ago(2)},
    );
    final xy = x.merge(y), yx = y.merge(x);
    expect(xy.matches(yx), true);
    expect(xy.merge(y).matches(xy), true);
    expect(xy.series.single.reached, (season: 1, episode: 2));
  });

  test('round-trips through JSON', () {
    final snap = _snap(
      [following(_a, episode: 2).copyWith(notifyAt: _ago(1))],
      {_b.id: _ago(4)},
    );
    expect(FollowedSnapshot.fromJson(snap.toJson()).matches(snap), true);
  });

  test('the notifier remembers unfollows and merges incoming', () async {
    final repository = MemoryFollowedSeries();
    final container = ProviderContainer(
      overrides: followedSeriesOverrides([
        following(_a, episode: 1, watchedAt: _ago(30)),
      ], repository),
    );
    addTearDown(container.dispose);
    final notifier = container.read(followedSeriesProvider.notifier);
    await notifier.unfollow(_a.id);
    expect(notifier.snapshot.removals.keys, [_a.id]);
    await notifier.merge(
      _snap([
        following(_a, episode: 1, watchedAt: _ago(40)),
        following(_b, episode: 5, watchedAt: _ago(1)),
      ]),
    );
    expect(
      [for (final s in container.read(followedSeriesProvider)) s.id],
      [_b.id],
    );
    final saves = repository.saved;
    await notifier.merge(notifier.snapshot);
    expect(identical(repository.saved, saves), true);
  });
}
