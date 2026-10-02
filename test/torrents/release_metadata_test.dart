import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/parsing.dart';
import 'package:sentorr/torrents/release_metadata.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Anitomy exposes every explicit range bound rather than only first episode',
    () {
      final parsed = ReleaseMetadata.parse('Breaking.Bad.S01E01-E03.1080p');
      expect(parsed.seasons, [1]);
      expect(parsed.episodes, [1, 3]);
    },
  );
  test(
    'adapter normalizes bare scene season packs and season-zero specials',
    () {
      expect(ReleaseMetadata.parse('Breaking.Bad.S01.Complete.1080p').seasons, [
        1,
      ]);
      final special = ReleaseMetadata.parse('Doctor.Who.S00E00.1080p');
      expect(special.seasons, [0]);
      expect(special.episodes, [0]);
    },
  );
  test('season pack release years are not invented episode numbers', () {
    expect(
      matchesRelease(
        TorrentQuery(title: 'The Office', year: 2005, season: 2),
        'The.Office.2005.S02.Complete.1080p',
      ),
      isTrue,
    );
  });
  test(
    'numeric movie titles preserve identity and separate actual release years',
    () {
      expect(
        matchesRelease(
          TorrentQuery(title: '2001: A Space Odyssey', year: 1968),
          '2001.A.Space.Odyssey.1968.1080p',
        ),
        isTrue,
      );
      expect(
        matchesRelease(
          TorrentQuery(title: '2001: A Space Odyssey', year: 1968),
          '2001.A.Space.Odyssey.2001.1080p',
        ),
        isFalse,
      );
    },
  );
}
