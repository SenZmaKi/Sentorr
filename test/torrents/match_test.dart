import 'package:sentorr/torrents/match.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:sentorr/torrents/resolver.dart';
import 'package:test/test.dart';

import '../support/fake_torrents.dart';

TorrentResolution _resolution(List<TorrentRelease> releases) =>
    TorrentResolution(
      query: TorrentQuery(title: 'Title 1'),
      candidates: TorrentResolver.rank(releases, TorrentPreferences()),
      failures: const [],
    );

void main() {
  final prefs = TorrentPreferences();

  test('the preferred quality in a single file is exact', () {
    final match = TorrentMatch.of(_resolution([fakeRelease(1)]), prefs)!;
    expect(match.exact, isTrue);
    expect(match.concerns, isEmpty);
  });

  test('quality compromises ask first but season packs remain exact', () {
    expect(
      TorrentMatch.of(
        _resolution([fakeRelease(1, resolution: 720)]),
        prefs,
      )!.concerns,
      [MatchConcern.otherResolution],
    );
    expect(
      TorrentMatch.of(
        _resolution([fakeRelease(1, resolution: null)]),
        prefs,
      )!.concerns,
      [MatchConcern.unknownResolution],
    );
    final pack = TorrentMatch.of(
      _resolution([fakeRelease(1, pack: true)]),
      prefs,
    )!;
    expect(pack.exact, isTrue);
    expect(pack.concerns, [MatchConcern.seasonPack]);
  });

  test('a season pack with other or unknown quality still asks first', () {
    for (final quality in <int?>[720, null]) {
      final match = TorrentMatch.of(
        _resolution([fakeRelease(1, pack: true, resolution: quality)]),
        prefs,
      )!;
      expect(match.exact, isFalse);
      expect(match.concerns, contains(MatchConcern.seasonPack));
    }
  });

  test('a miss has no match', () {
    expect(TorrentMatch.of(_resolution([]), prefs), isNull);
  });

  test('concerns name the preference they compromise', () {
    expect(
      MatchConcern.otherResolution.describe(
        TorrentPreferences(preferredResolution: 2160),
      ),
      contains('2160p'),
    );
  });
}
