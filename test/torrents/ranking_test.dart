import 'package:sentorr/torrents/diagnostics.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:sentorr/torrents/resolver.dart';
import 'package:test/test.dart';

import 'resolver_test.dart' show release;

void main() {
  test('series packs use the same unknown-size policy as season packs', () {
    final season = release(1, pack: true, size: 5 * 1024 * 1024 * 1024);
    final series = TorrentRelease(
      source: season.source,
      name: season.name,
      infoHash: season.infoHash,
      magnet: season.magnet,
      seeders: season.seeders,
      resolution: season.resolution,
      sizeBytes: 50 * 1024 * 1024 * 1024,
      isSeriesPack: true,
    );
    final prefs = TorrentPreferences();
    final candidate = TorrentResolver.rank([series], prefs).single;
    expect(candidate.score, TorrentResolver.rank([season], prefs).single.score);
    expect(candidate.requiresFileSelection, isTrue);
  });
  test('unknown episode size is independent of total season size', () {
    final prefs = TorrentPreferences();
    final small = TorrentResolver.rank([
      release(1, pack: true, size: 5 * 1024 * 1024 * 1024),
    ], prefs).single;
    final large = TorrentResolver.rank([
      release(1, pack: true, size: 50 * 1024 * 1024 * 1024),
    ], prefs).single;
    expect(large.score, small.score);
    expect(large.requiresFileSelection, isTrue);
  });
  test('unknown pack size sits between known small and large episodes', () {
    final ranked = TorrentResolver.rank([
      release(1, seeders: 190, size: 489 * 1024 * 1024),
      release(2, seeders: 190, pack: true, size: 20 * 1024 * 1024 * 1024),
      release(3, seeders: 190, size: 2200 * 1024 * 1024),
    ], TorrentPreferences());
    expect(ranked.map((c) => c.release.infoHash), [
      release(1).infoHash,
      release(2).infoHash,
      release(3).infoHash,
    ]);
  });
  test('unknown pack size does not rescue an unhealthy swarm', () {
    final ranked = TorrentResolver.rank([
      release(1, seeders: 2, pack: true, size: 20 * 1024 * 1024 * 1024),
      release(2, seeders: 190, size: 2200 * 1024 * 1024),
    ], TorrentPreferences());
    expect(ranked.first.release.infoHash, release(2).infoHash);
  });
  test('smaller episode outweighs a modest healthy-swarm advantage', () {
    for (final seeds in [240, 250]) {
      final ranked = TorrentResolver.rank([
        release(1, seeders: seeds, size: 2200 * 1024 * 1024),
        release(2, seeders: 190, size: 489 * 1024 * 1024),
      ], TorrentPreferences());
      expect(ranked.first.release.infoHash, release(2).infoHash);
    }
  });
  test('tiny poorly seeded release does not beat a healthy larger swarm', () {
    final ranked = TorrentResolver.rank([
      release(1, seeders: 2, size: 100 * 1024 * 1024),
      release(2, seeders: 250, size: 2200 * 1024 * 1024),
    ], TorrentPreferences());
    expect(ranked.first.release.infoHash, release(2).infoHash);
  });
  test('a substantial swarm advantage can justify a larger release', () {
    final ranked = TorrentResolver.rank([
      release(1, seeders: 2000, size: 2200 * 1024 * 1024),
      release(2, seeders: 190, size: 489 * 1024 * 1024),
    ], TorrentPreferences());
    expect(ranked.first.release.infoHash, release(1).infoHash);
  });
  test('Lanterns slightly larger well-seeded release wins above 100 seeds', () {
    final ranked = TorrentResolver.rank([
      release(1, seeders: 703, size: 482 * 1024 * 1024),
      release(2, seeders: 2392, size: 526 * 1024 * 1024),
    ], TorrentPreferences());
    expect(ranked.first.release.seeders, 2392);
  });
  test('seeder counts influence selection when quality and size are equal', () {
    final ranked = TorrentResolver.rank([
      release(1, seeders: 1),
      release(2, seeders: 50),
    ], TorrentPreferences());
    expect(ranked.first.release.seeders, 50);
  });
  test('availability keeps increasing beyond 100 with diminishing returns', () {
    double availability(int seeds) => TorrentResolver.rank([
      release(1, seeders: seeds),
    ], TorrentPreferences()).single.availabilityScore;
    final scores = [100, 703, 2392, 4934, 10000].map(availability).toList();
    for (var i = 1; i < scores.length; i++) {
      expect(scores[i], greaterThan(scores[i - 1]));
      expect(scores[i], lessThan(1));
    }
    expect(
      availability(200) - availability(100),
      greaterThan(availability(1100) - availability(1000)),
    );
  });
  test('smaller torrent wins when quality and seeds are equal', () {
    final ranked = TorrentResolver.rank([
      release(1, size: 8000000000),
      release(2, size: 1000000000),
    ], TorrentPreferences());
    expect(ranked.first.release.sizeBytes, 1000000000);
  });
  test('user preferred resolution changes the selected release', () {
    final releases = [
      release(1, resolution: 720),
      release(2, resolution: 1080),
    ];
    expect(
      TorrentResolver.rank(
        releases,
        TorrentPreferences(preferredResolution: 720),
      ).first.release.resolution,
      720,
    );
    expect(
      TorrentResolver.rank(
        releases,
        TorrentPreferences(preferredResolution: 1080),
      ).first.release.resolution,
      1080,
    );
  });
  test('filter reports distinguish unknown quality, low seeds and size', () {
    final reasons = <TorrentRejection>[];
    TorrentResolver.rank(
      [
        release(1, resolution: null),
        release(2, seeders: 1),
        release(3, size: 8000000000),
      ],
      TorrentPreferences(
        minimumSeeders: 5,
        maximumSizeBytes: 2000000000,
        allowUnknownResolution: false,
      ),
      onRejected: reasons.add,
    );
    expect(reasons, [
      TorrentRejection.unknownResolution,
      TorrentRejection.insufficientSeeders,
      TorrentRejection.sizeLimit,
    ]);
  });
  test(
    'unconfigured sources are unavailable with an actionable explanation',
    () async {
      final result = await TorrentResolver(TorrentRepository([]))
          .resolve(TorrentQuery(title: 'Breaking Bad', season: 1, episode: 1));
      expect(result.status, TorrentResolutionStatus.unavailable);
      expect(result.message, 'No configured source supports this request.');
    },
  );
}
