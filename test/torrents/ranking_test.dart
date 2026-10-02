import 'package:sentorr/torrents/diagnostics.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/repository.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:sentorr/torrents/resolver.dart';
import 'package:test/test.dart';

import 'resolver_test.dart' show release;

void main() {
  test('seeder counts influence selection when quality and size are equal', () {
    final ranked = TorrentResolver.rank([
      release(1, seeders: 1),
      release(2, seeders: 50),
    ], TorrentPreferences());
    expect(ranked.first.release.seeders, 50);
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
