import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/parsing.dart';
import 'package:test/test.dart';

const hash = '0123456789abcdef0123456789abcdef01234567';
void main() {
  test('resolution accepts underscore-delimited release names', () {
    expect(resolutionOf('big_buck_bunny_1080p_h264.mov'), 1080);
  });
  final movie = TorrentQuery(title: 'Big Buck Bunny', year: 2008);

  test('series year disambiguates reboots when present', () {
    final query = TorrentQuery(
      title: 'The Office',
      year: 2005,
      season: 1,
      episode: 1,
    );
    expect(matchesRelease(query, 'The.Office.2024.S01E01.480p'), isFalse);
    expect(matchesRelease(query, 'The.Office.2005.S01E01.1080p'), isTrue);
    expect(resolutionOf('The.Office.S01.Multi.WebRip1080p'), 1080);
  });

  test('search languages are immutable and ISO codes match filename names', () {
    final languages = {'en'};
    final query = TorrentQuery(title: 'Example Movie', languages: languages);
    languages.clear();
    expect(query.languages, {'en'});
    expect(matchesRelease(query, 'Example.Movie.2020.1080p.English'), isTrue);
    expect(() => query.languages.add('fr'), throwsUnsupportedError);
  });
  test(
    'title comparison uses both inputs and does not accept unrelated titles',
    () {
      expect(
        titleSimilarity('Big Buck Bunny', 'Something Different'),
        lessThan(.5),
      );
      expect(titleSimilarity('', ''), 0);
      expect(matchesRelease(movie, 'Something.Different.2008.1080p'), isFalse);
      expect(matchesRelease(movie, 'Big.Buck.Bunny.2008.1080p'), isTrue);
      expect(matchesRelease(movie, 'Big.Buck.Bunny.2009.1080p'), isFalse);
      expect(
        matchesRelease(TorrentQuery(title: 'Alien'), 'Aliens.1986.1080p'),
        isFalse,
      );
      expect(
        matchesRelease(TorrentQuery(title: 'Movie 2'), 'Movie.3.2020.1080p'),
        isFalse,
      );
    },
  );
  test(
    'sequels and movie collections are rejected even with matching IMDb',
    () {
      expect(
        matchesRelease(
          TorrentQuery(title: 'A Very Long Movie Title'),
          'A.Very.Long.Movie.Title.2.2020.1080p',
        ),
        isFalse,
      );
      expect(
        matchesRelease(
          TorrentQuery(title: 'The Matrix'),
          'The Matrix 1-4 Pack 1999-2021 1080p',
          trustedIdentity: true,
        ),
        isFalse,
      );
    },
  );
  test('numeric title words are not mistaken for release year', () {
    expect(
      matchesRelease(
        TorrentQuery(title: '1917', year: 2019),
        '1917.2019.1080p',
      ),
      isTrue,
    );
    expect(
      matchesRelease(
        TorrentQuery(title: '2001 A Space Odyssey', year: 1968),
        '2001.A.Space.Odyssey.1968.1080p',
      ),
      isTrue,
    );
    expect(
      matchesRelease(
        TorrentQuery(title: '1917', year: 2019),
        '1917.2020.1080p',
      ),
      isFalse,
    );
  });
  test('episode zero, exact seasons and pack separation', () {
    final episode = TorrentQuery(title: 'Example Show', season: 2, episode: 0);
    final pack = TorrentQuery(title: 'Example Show', season: 2);
    expect(episode.searchText, 'Example Show S02E00');
    expect(matchesRelease(episode, 'Example.Show.S02E00.1080p'), isTrue);
    expect(matchesRelease(episode, 'Example.Show.S01E00.1080p'), isFalse);
    expect(matchesRelease(episode, 'Example.Show.S02E01.1080p'), isFalse);
    expect(matchesRelease(episode, 'Example.Show.S02.1080p'), isFalse);
    expect(matchesRelease(pack, 'Example.Show.S02.1080p'), isTrue);
    expect(
      matchesRelease(pack, 'Example.Show.Season.2.Complete.1080p'),
      isTrue,
    );
    expect(matchesRelease(pack, 'Example.Show.S02E01.1080p'), isFalse);
    expect(
      matchesRelease(pack, 'Example.Show.Season.2.Episode.1.1080p'),
      isFalse,
    );
    expect(
      matchesRelease(pack, 'Example.Show.S02-S04.Complete.1080p'),
      isFalse,
    );
    expect(matchesRelease(episode, 'Example.Show.S02E00E01.1080p'), isFalse);
  });
  test(
    'explicit language filters do not invent English for unknown releases',
    () {
      final query = TorrentQuery(
        title: 'Example Movie',
        languages: {'English'},
      );
      expect(matchesRelease(query, 'Example.Movie.2020.1080p'), isFalse);
      expect(matchesRelease(query, 'Example.Movie.2020.1080p.English'), isTrue);
      expect(matchesRelease(query, 'Example.Movie.2020.1080p.French'), isFalse);
    },
  );
  test('hashes and sizes are validated and binary units are supported', () {
    expect(infoHash('0' * 40), isNull);
    expect(infoHash('bad'), isNull);
    expect(infoHash(hash.toUpperCase()), hash);
    expect(magnetHash(magnetFor(hash, 'A & B')), hash);
    expect(magnetFor(hash, 'A & B').queryParameters['dn'], 'A & B');
    expect(magnetHash(Uri.parse('https://example.com/$hash')), isNull);
    expect(parseSize('1.5 GiB'), 1610612736);
    expect(parseSize('2 MB'), 2097152);
    expect(parseSize('1..2 GB'), isNull);
    expect(unixDate('bad'), isNull);
    expect(unixDate('999999999999999999'), isNull);
  });
  test('invalid query intent is rejected', () {
    expect(() => TorrentQuery(title: ''), throwsArgumentError);
    expect(() => TorrentQuery(title: 'Title', episode: 1), throwsArgumentError);
    expect(
      () => TorrentQuery(title: 'Title', imdbId: 'bad'),
      throwsArgumentError,
    );
  });
}
