import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/subtitle_files.dart';
import 'package:torrent_stream/torrent_stream.dart';

TorrentStreamFile f(int index, String path, {int length = 100}) =>
    TorrentStreamFile(
      index: index,
      path: path,
      length: length,
      isPadFile: false,
    );

void main() {
  final movie = PlaybackItem(
    title: ImdbTitle(id: 'tt1', title: 'Movie'),
  );
  final episode = PlaybackItem(
    title: ImdbTitle(id: 'tt2', title: 'Pilot'),
    series: ImdbTitle(id: 'tt3', title: 'Show'),
    season: 1,
    episode: 2,
  );
  test(
    'single movie includes named and generic Subs SRTs, not other formats',
    () {
      final video = f(0, 'Movie/Movie.mkv');
      final files = [
        video,
        f(1, 'Movie/Movie.en.SRT'),
        f(2, 'Movie/Subs/English.srt'),
        f(3, 'Movie/English.ass'),
        f(4, 'Movie/huge.srt', length: 6 * 1024 * 1024),
      ];
      expect(subtitleFiles(files, video, movie).map((s) => s.index), [1, 2]);
    },
  );
  test(
    'episode packs keep only subtitles for the selected episode and season',
    () {
      final video = f(0, 'Show/Season 1/Show.S01E02.mkv');
      final files = [
        video,
        f(1, 'Show/Season 1/Show.S01E01.mkv'),
        f(2, 'Show/Season 1/Show.S01E02.en.srt'),
        f(3, 'Show/Season 1/Show.S01E01.en.srt'),
        f(4, 'Show/Season 2/Show.S02E02.en.srt'),
        f(5, 'Show/Subs/Show.S01E02/French.srt'),
        f(6, 'Show/Subs/Show.S01E01/French.srt'),
      ];
      expect(subtitleFiles(files, video, episode).map((s) => s.index), [2, 5]);
    },
  );
  test('multiple movies do not acquire ambiguous generic subtitles', () {
    final video = f(0, 'Movie.mkv');
    expect(
      subtitleFiles(
        [video, f(1, 'Other.mkv'), f(2, 'English.srt'), f(3, 'Movie.en.srt')],
        video,
        movie,
      ).map((s) => s.index),
      [3],
    );
  });
}
