import 'package:sentorr/torrents/diagnostics.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:sentorr/torrents/resolver.dart';
import 'package:test/test.dart';

import 'resolver_test.dart' show release;

void main() {
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
