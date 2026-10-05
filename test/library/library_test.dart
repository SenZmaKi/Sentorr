import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/layout.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/player/models.dart';

import '../support/fake_imdb.dart';
import '../support/fake_torrents.dart';

PlaybackItem episode({int season = 1, int number = 3}) => PlaybackItem(
  title: ImdbTitle(id: 'tt90', title: 'The Pilot'),
  series: ImdbTitle(id: 'tt9', title: 'Show: Reborn?', releaseYear: 2019),
  season: season,
  episode: number,
);

LibraryEntry entry(PlaybackItem item) => LibraryEntry(
  item: item,
  downloadId: 'd1',
  release: fakeRelease(1, name: 'Show S01E03 1080p', pack: true),
  fileIndex: 2,
  path: '/downloads/Show Reborn (2019)/Season 01/Show Reborn S01E03.mkv',
  addedAt: DateTime(2026, 10, 2),
  automatic: true,
);

void main() {
  test(
    'saved metadata downloads retain tracker discovery without a magnet',
    () {
      final job = TorrentDownloadJob(
        title: 'Movie',
        destinationDirectory: '/downloads',
        torrentData: Uint8List.fromList('d4:infodee'.codeUnits),
        trackers: [Uri.parse('https://tracker.test/announce')],
      );
      final restored = TorrentDownloadJob.fromJson(job.toJson());
      expect(restored.magnet, isNull);
      expect(restored.torrentData, job.torrentData);
      expect(restored.trackers, job.trackers);
    },
  );
  test(
    'release metadata URLs survive persistence and old records remain readable',
    () {
      final json = releaseToJson(fakeRelease(1));
      json['torrentUrls'] = ['https://provider.test/movie.torrent'];
      final release = releaseFromJson(json)!;
      expect(releaseToJson(release)['torrentUrls'], json['torrentUrls']);
      json.remove('torrentUrls');
      expect(releaseFromJson(json)!.torrentUrls, isEmpty);
    },
  );
  test('movies get a titled folder and episodes a season folder', () {
    final movie = layoutFor(
      PlaybackItem(title: fakeTitle(1, year: 2024)),
      '/d',
      'Release.2024.1080p/Title.1.2024.MKV',
    );
    expect(movie.directory, p.join('/d', 'Title 1 (2024)'));
    expect(movie.name, 'Title 1 (2024).mkv');
    final show = layoutFor(episode(season: 2, number: 11), '/d', 'x.mp4');
    expect(show.directory, p.join('/d', 'Show Reborn (2019)'));
    expect(show.name, p.join('Season 02', 'Show Reborn S02E11.mp4'));
  });

  test('names drop characters file systems reject', () {
    expect(safeName('A/B\\C:D*E?"F<G>H|I'), 'A B C D E F G H I');
    expect(safeName('Trailing... '), 'Trailing');
    expect(safeName('***'), 'Untitled');
    expect(safeName('x' * 300).length, 120);
  });

  test('entries survive a save and load', () {
    final saved = LibraryEntry.fromJson(entry(episode()).toJson())!;
    expect(saved.id, 'tt90');
    expect(saved.item.series!.title, 'Show: Reborn?');
    expect(saved.item.season, 1);
    expect(saved.item.episode, 3);
    expect(saved.release.infoHash, fakeRelease(1).infoHash);
    expect(saved.release.isSeasonPack, true);
    expect(saved.fileIndex, 2);
    expect(saved.automatic, true);
    expect(LibraryEntry.fromJson({'title': 'nope'}), isNull);
  });

  test('download status maps onto offline state', () {
    final e = entry(episode());
    DownloadItem at(DownloadStatus s, {int done = 50}) => DownloadItem(
      id: 'd1',
      job: TorrentDownloadJob(
        title: 'x',
        magnet: Uri.parse('magnet:?xt=urn:btih:1'),
        destinationDirectory: '/d',
      ),
      status: s,
      files: [DownloadFileProgress(2, 'x.mkv', 100, done)],
    );
    expect(offlineStateOf(e, at(DownloadStatus.completed)), isA<Downloaded>());
    expect(offlineStateOf(e, at(DownloadStatus.seeding)), isA<Downloaded>());
    expect(offlineStateOf(e, at(DownloadStatus.failed)), isA<DownloadFailed>());
    final moving = offlineStateOf(e, at(DownloadStatus.downloading));
    expect(moving, isA<Downloading>());
    expect((moving as Downloading).progress, .5);
    expect(
      (offlineStateOf(e, at(DownloadStatus.paused)) as Downloading).status,
      OfflineProgress.paused,
    );
    // Cleared from download history with its file gone.
    expect(offlineStateOf(e, null), isA<DownloadFailed>());
  });
}
