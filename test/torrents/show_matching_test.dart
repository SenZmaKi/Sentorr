import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/parsing.dart';
import 'package:test/test.dart';

void main() {
  final breakingBad = TorrentQuery(
    title: 'Breaking Bad',
    season: 1,
    episode: 1,
  );
  final office = TorrentQuery(
    title: 'The Office',
    year: 2005,
    season: 2,
    episode: 3,
  );
  final cases = <({TorrentQuery query, String name, bool matches})>[
    (
      query: TorrentQuery(
        title: 'Breaking Bad',
        season: 1,
        episode: 1,
        languages: {'en'},
      ),
      name: 'Breaking.Bad.S01E01.[English Subs].1080p',
      matches: false,
    ),
    (
      query: TorrentQuery(
        title: 'Breaking Bad',
        season: 1,
        episode: 1,
        languages: {'en'},
      ),
      name: 'Breaking.Bad.S01E01.Subtitles.English.1080p',
      matches: false,
    ),
    (
      query: breakingBad,
      name: 'Breaking.Bad.S01E01.1080p.WEB-DL',
      matches: true,
    ),
    (query: breakingBad, name: 'Breaking_Bad_s01e01_720p_HDTV', matches: true),
    (
      query: breakingBad,
      name: '[Group] Breaking Bad Season 1 Episode 1 1080p',
      matches: true,
    ),
    (query: breakingBad, name: 'Breaking Bad 1x01 1080p HDTV', matches: true),
    (query: breakingBad, name: 'Breaking.Bad.S01E02.1080p', matches: false),
    (query: breakingBad, name: 'Breaking.Bad.S02E01.1080p', matches: false),
    (
      query: breakingBad,
      name: 'Breaking.Bad.S01.Complete.1080p',
      matches: false,
    ),
    (query: breakingBad, name: 'Breaking.Bad.S01E01-E03.1080p', matches: false),
    (query: breakingBad, name: 'Breaking.Bad.S01E01E02.1080p', matches: false),
    (query: breakingBad, name: 'Breaking.Bad.S01E01 E02.1080p', matches: false),
    (
      query: breakingBad,
      name: 'Breaking Bad Season 1 Episode 1-3 1080p',
      matches: false,
    ),
    (
      query: breakingBad,
      name: 'Breaking.Bad.S01-S05.Complete.1080p',
      matches: false,
    ),
    (
      query: breakingBad,
      name: 'Breaking.Bad.S01.S02.Complete.1080p',
      matches: false,
    ),
    (query: breakingBad, name: 'Better.Call.Saul.S01E01.1080p', matches: false),
    (query: office, name: 'The.Office.2005.S02E03.1080p', matches: true),
    (query: office, name: 'The.Office.2001.S02E03.1080p', matches: false),
    (query: office, name: 'The.Office.S02E03.1080p', matches: true),
    (
      query: TorrentQuery(title: '1899', year: 2022, season: 1, episode: 1),
      name: '1899.2022.S01E01.1080p',
      matches: true,
    ),
    (
      query: TorrentQuery(title: '24', season: 2, episode: 3),
      name: '24.S02E03.1080p',
      matches: true,
    ),
    (
      query: TorrentQuery(title: 'Planet Earth', season: 1, episode: 1),
      name: 'Planet.Earth.II.S01E01.1080p',
      matches: false,
    ),
    (
      query: TorrentQuery(title: 'Doctor Who', season: 0, episode: 0),
      name: 'Doctor.Who.S00E00.1080p',
      matches: true,
    ),
    (
      query: TorrentQuery(title: 'Lupin', season: 1, episode: 1),
      name: 'Lupin.S01E01.1080p',
      matches: true,
    ),
    (
      query: TorrentQuery(title: 'Lupin', season: 1, episode: 1),
      name: 'Lupine.S01E01.1080p',
      matches: false,
    ),
    (
      query: TorrentQuery(title: 'Shōgun', season: 1, episode: 1),
      name: 'Shōgun.S01E01.1080p',
      matches: true,
    ),
    (
      query: TorrentQuery(title: 'Breaking Bad', season: 1),
      name: 'Breaking.Bad.S01.Complete.1080p',
      matches: true,
    ),
    (
      query: TorrentQuery(title: 'Breaking Bad', season: 1),
      name: 'Breaking.Bad.Season.1.1080p',
      matches: true,
    ),
    (
      query: TorrentQuery(title: 'Breaking Bad', season: 1),
      name: 'Breaking.Bad.S01E01.1080p',
      matches: false,
    ),
    (
      query: TorrentQuery(
        title: 'Breaking Bad',
        season: 1,
        episode: 1,
        languages: {'en'},
      ),
      name: 'Breaking.Bad.S01E01.English.1080p',
      matches: true,
    ),
    (
      query: TorrentQuery(
        title: 'Breaking Bad',
        season: 1,
        episode: 1,
        languages: {'English'},
      ),
      name: 'Breaking.Bad.S01E01.[ENG].1080p',
      matches: true,
    ),
    (
      query: TorrentQuery(
        title: 'Breaking Bad',
        season: 1,
        episode: 1,
        languages: {'fr'},
      ),
      name: 'Breaking.Bad.S01E01.French.1080p',
      matches: true,
    ),
    (
      query: TorrentQuery(
        title: 'Breaking Bad',
        season: 1,
        episode: 1,
        languages: {'fr'},
      ),
      name: 'Breaking.Bad.S01E01.English.1080p',
      matches: false,
    ),
    (
      query: TorrentQuery(
        title: 'Breaking Bad',
        season: 1,
        episode: 1,
        languages: {'en'},
      ),
      name: 'Breaking.Bad.S01E01.MULTI.1080p',
      matches: false,
    ),
    (
      query: TorrentQuery(
        title: 'Breaking Bad',
        season: 1,
        episode: 1,
        languages: {'en'},
      ),
      name: 'Breaking.Bad.S01E01.1080p',
      matches: false,
    ),
    (
      query: TorrentQuery(
        title: 'The English',
        season: 1,
        episode: 1,
        languages: {'en'},
      ),
      name: 'The.English.S01E01.1080p',
      matches: false,
    ),
  ];
  for (final c in cases) {
    test('${c.query.searchText} matches=${c.matches}: ${c.name}', () {
      expect(matchesRelease(c.query, c.name), c.matches);
    });
  }
}
