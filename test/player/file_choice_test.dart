import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/file_choice.dart';
import 'package:torrent_stream/torrent_stream.dart';

var _index = 0;
TorrentStreamFile _file(String path, int length, {bool pad = false}) =>
    TorrentStreamFile(
      index: _index++,
      path: path,
      length: length,
      isPadFile: pad,
    );

final _movie = PlaybackItem(
  title: ImdbTitle(id: 'tt1', title: 'Movie'),
);
PlaybackItem _episode(int season, int episode) => PlaybackItem(
  title: ImdbTitle(id: 'tt9', title: 'Episode'),
  series: ImdbTitle(id: 'tt2', title: 'Show'),
  season: season,
  episode: episode,
);

void main() {
  test('series batch chooses exact season and episode from nested folders', () {
    final requested = _file('Show Complete/Season 2/02 - Name.mkv', 900);
    final files = [
      _file('Show Complete/Season 1/02 - Name.mkv', 4000),
      requested,
    ];
    expect(
      playableFile(files, _episode(2, 2), pack: true, seriesPack: true),
      requested,
    );
  });
  test('series batch with bare episode numbers and no season fails closed', () {
    expect(
      playableFile(
        [_file('Show Complete/02 - Name.mkv', 900)],
        _episode(2, 2),
        pack: true,
        seriesPack: true,
      ),
      isNull,
    );
  });
  test('series batch accepts explicit season and episode filenames', () {
    final requested = _file('Show Complete/Show.S02E03.mkv', 900);
    expect(
      playableFile(
        [_file('Show Complete/Show.S01E03.mkv', 4000), requested],
        _episode(2, 3),
        pack: true,
        seriesPack: true,
      ),
      requested,
    );
  });
  test('packs never substitute a sample or combined-episode video', () {
    expect(
      playableFile(
        [_file('Show.S02E03.sample.mkv', 900)],
        _episode(2, 3),
        pack: true,
      ),
      isNull,
    );
    expect(
      playableFile(
        [_file('Show.S02E01-E03.mkv', 900)],
        _episode(2, 3),
        pack: true,
        seriesPack: true,
      ),
      isNull,
    );
  });
  test('a movie plays its largest video, not samples or other files', () {
    final feature = _file('Movie 2020/Movie.2020.1080p.mkv', 4000);
    final files = [
      _file('Movie 2020/Movie.2020.1080p.Sample.mkv', 50),
      feature,
      _file('Movie 2020/Movie.2020.nfo', 9000),
      _file('.pad/0', 8000, pad: true),
    ];
    expect(playableFile(files, _movie, pack: false), feature);
  });

  test('a sample plays when it is the only video', () {
    final sample = _file('Movie/sample.mp4', 50);
    expect(
      playableFile([sample, _file('Movie/info.txt', 10)], _movie, pack: false),
      sample,
    );
  });

  test('a season pack plays the requested episode', () {
    final third = _file('Show S01/Show.S01E03.1080p.mkv', 900);
    final files = [
      _file('Show S01/Show.S01E01.1080p.mkv', 1000),
      _file('Show S01/Show.S01E02.1080p.mkv', 1100),
      third,
    ];
    expect(playableFile(files, _episode(1, 3), pack: true), third);
  });

  test('a season folder supplies the season of bare episode files', () {
    final second = _file('Show Season 2/02 - Name.mkv', 900);
    final files = [_file('Show Season 2/01 - Name.mkv', 1000), second];
    expect(playableFile(files, _episode(2, 2), pack: true), second);
  });

  test('a pack without the episode plays nothing', () {
    final files = [
      _file('Show S01/Show.S01E01.mkv', 1000),
      _file('Show S01/Show.S01E02.mkv', 1000),
    ];
    expect(playableFile(files, _episode(1, 5), pack: true), isNull);
  });

  test('a single-episode torrent plays its video whatever its name', () {
    final video = _file('show-103-x264/video.mkv', 1000);
    expect(playableFile([video], _episode(1, 3), pack: false), video);
  });
}
