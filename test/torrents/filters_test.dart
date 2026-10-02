import 'package:sentorr/torrents/filters.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/release_traits.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:sentorr/torrents/resolver.dart';
import 'package:test/test.dart';

import '../support/fake_torrents.dart';

List<TorrentCandidate> _ranked(List<TorrentRelease> releases) =>
    TorrentResolver.rank(releases, TorrentPreferences());

void main() {
  final candidates = _ranked([
    fakeRelease(1, name: 'Film 2026 1080p WEB-DL x264', seeders: 40),
    fakeRelease(
      2,
      name: 'Film 2026 2160p BluRay HDR x265',
      seeders: 10,
      resolution: 2160,
      size: 20 * 1024 * 1024 * 1024,
    ),
    fakeRelease(
      3,
      name: 'Film 2026 720p HDTV x264-GRP',
      seeders: 300,
      resolution: 720,
      size: 700 * 1024 * 1024,
    ),
    fakeRelease(
      4,
      name: 'Film 2026 Season 1 Pack',
      resolution: null,
      pack: true,
      seeders: 5,
    ),
  ]);
  int id(TorrentCandidate c) => int.parse(c.release.infoHash, radix: 16);

  test('no filters keep the resolver order', () {
    final shown = const TorrentFilters().apply(candidates);
    expect(shown.map(id), candidates.map(id));
  });

  test('each dimension narrows on its own', () {
    List<int> ids(TorrentFilters f) => f.apply(candidates).map(id).toList();
    expect(ids(const TorrentFilters(qualities: {QualityBand.uhd})), [2]);
    expect(ids(const TorrentFilters(qualities: {QualityBand.unknown})), [4]);
    expect(ids(const TorrentFilters(origins: {VideoOrigin.web})), [1]);
    expect(
      ids(const TorrentFilters(codecs: {VideoCodec.h264})),
      unorderedEquals([1, 3]),
    );
    expect(ids(const TorrentFilters(hdrOnly: true)), [2]);
    expect(ids(const TorrentFilters(pack: PackMode.season)), [4]);
    expect(
      ids(const TorrentFilters(pack: PackMode.episode)),
      isNot(contains(4)),
    );
    expect(ids(const TorrentFilters(minSeeders: 25)), unorderedEquals([1, 3]));
    expect(ids(const TorrentFilters(maxGigabytes: 1)), [3]);
    expect(ids(const TorrentFilters(minGigabytes: 10)), [2]);
    expect(ids(const TorrentFilters(nameContains: 'grp')), [3]);
    expect(ids(const TorrentFilters(sources: {TorrentSourceId.yts})), isEmpty);
  });

  test('sorts order by their measure, ties by rank', () {
    List<int> ids(TorrentSort s) =>
        TorrentFilters(sort: s).apply(candidates).map(id).toList();
    expect(ids(TorrentSort.seeders), [3, 1, 2, 4]);
    expect(ids(TorrentSort.quality).first, 2);
    expect(ids(TorrentSort.quality).last, 4);
    expect(ids(TorrentSort.largest).first, 2);
    expect(ids(TorrentSort.smallest).first, 3);
  });

  test('active count ignores the sort, and clearing keeps it', () {
    const f = TorrentFilters(
      sort: TorrentSort.seeders,
      hdrOnly: true,
      minSeeders: 5,
      maxGigabytes: 4,
    );
    expect(f.activeCount, 3);
    expect(f.cleared().activeCount, 0);
    expect(f.cleared().sort, TorrentSort.seeders);
    expect(f.copyWith(gigabytes: (null, null)).activeCount, 2);
  });
}
