import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/torrent_lookup.dart';
import 'package:sentorr/settings/models.dart';

void main() {
  test('a movie searches its title, year and IMDb identity', () {
    final query = torrentQueryFor(
      PlaybackItem(
        title: ImdbTitle(id: 'tt1', title: 'Movie', releaseYear: 2020),
      ),
      languages: {'en'},
    );
    expect(query.searchText, 'Movie 2020');
    expect(query.imdbId, 'tt1');
    expect(query.isSeries, isFalse);
    expect(query.languages, {'en'});
  });

  test('an episode searches its series with both identities', () {
    final query = torrentQueryFor(
      PlaybackItem(
        title: ImdbTitle(id: 'tt9', title: 'Pilot'),
        series: ImdbTitle(id: 'tt2', title: 'Show', releaseYear: 2005),
        season: 1,
        episode: 3,
      ),
    );
    expect(query.searchText, 'Show S01E03');
    expect(query.imdbId, 'tt2');
    expect(query.episodeImdbId, 'tt9');
    expect(query.year, 2005);
  });

  test('a typed title replaces the catalog name, not the identity', () {
    final query = torrentQueryFor(
      PlaybackItem(
        title: ImdbTitle(id: 'tt1', title: 'Movie'),
      ),
      title: 'Film',
    );
    expect(query.title, 'Film');
    expect(query.imdbId, 'tt1');
  });

  test('malformed IDs are left out; unnumbered episodes cannot search', () {
    final movie = torrentQueryFor(
      PlaybackItem(
        title: ImdbTitle(id: 'local', title: 'Movie'),
      ),
    );
    expect(movie.imdbId, isNull);
    expect(
      () => torrentQueryFor(
        PlaybackItem(
          title: ImdbTitle(id: 'tt9', title: 'Special'),
          series: ImdbTitle(id: 'tt2', title: 'Show'),
          season: 1,
        ),
      ),
      throwsFormatException,
    );
  });

  test('settings carry the preferred resolution and allow season packs', () {
    final prefs = torrentPreferencesFor(
      const TorrentSettings(preferredResolution: 720),
    );
    expect(prefs.preferredResolution, 720);
    expect(prefs.allowSeasonPackFallback, isTrue);
    expect(prefs.includeBatchCandidates, isTrue);
  });
  test('finished catalog series enable complete-series discovery', () {
    final query = torrentQueryFor(
      PlaybackItem(
        title: ImdbTitle(id: 'tt9', title: 'Episode'),
        series: ImdbTitle(
          id: 'tt2',
          title: 'Breaking Bad',
          releaseYear: 2008,
          endYear: 2013,
        ),
        season: 2,
        episode: 3,
      ),
    );
    expect(query.seriesEnded, isTrue);
    expect(query.episode, 3);
  });

  test('torrent settings survive a round trip and reject bad values', () {
    const settings = AppSettings(
      torrents: TorrentSettings(
        preferredResolution: 2160,
        languages: {'en'},
        reviewExactMatches: false,
      ),
    );
    final back = AppSettings.fromJson(settings.toJson()).torrents;
    expect(back.preferredResolution, 2160);
    expect(back.languages, {'en'});
    expect(back.reviewExactMatches, isFalse);
    final bad = TorrentSettings.fromJson({
      'preferredResolution': 999,
      'languages': [' ', 3],
    });
    expect(bad.preferredResolution, 1080);
    expect(bad.languages, isEmpty);
    expect(bad.reviewExactMatches, isTrue);
  });
}
