import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/smart_downloads/reserve.dart';
import 'package:sentorr/watching/models.dart';

import '../support/fake_following.dart';
import '../support/fake_imdb.dart';
import '../support/fake_torrents.dart';

final _series = fakeTitle(2, series: true);

PlaybackItem _movie(int n, {int? minutes = 90}) => PlaybackItem(
  title: ImdbTitle(
    id: 'tt$n',
    title: 'Movie $n',
    runtimeSeconds: minutes == null ? null : minutes * 60,
  ),
);

PlaybackItem _episode(int n) => PlaybackItem(
  title: ImdbTitle(id: 'tt2$n', title: 'Episode $n'),
  series: _series,
  season: 1,
  episode: n,
);

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-reserve-');
  });
  tearDown(() => root.delete(recursive: true));

  LibraryEntry entry(
    PlaybackItem item, {
    LibraryOrigin origin = LibraryOrigin.smart,
    bool onDisk = true,
  }) {
    final path = '${root.path}/${item.id}.mkv';
    if (onDisk) File(path).writeAsStringSync('video');
    return LibraryEntry(
      item: item,
      downloadId: 'd-${item.id}',
      release: fakeRelease(1),
      fileIndex: 0,
      path: path,
      addedAt: DateTime(2026),
      origin: origin,
    );
  }

  DownloadItem download(
    LibraryEntry e,
    DownloadStatus status, {
    int bytes = 1000,
  }) => DownloadItem(
    id: e.downloadId,
    job: TorrentDownloadJob(
      title: e.item.label,
      magnet: Uri.parse('magnet:?xt=urn:btih:1'),
      destinationDirectory: root.path,
    ),
    status: status,
    files: [DownloadFileProgress(0, 'x.mkv', bytes, 0)],
  );

  test('counts unwatched automatic downloads, ready and on the way', () {
    final ready = entry(_movie(1));
    final coming = entry(_episode(1), onDisk: false);
    final series = entry(_episode(2), origin: LibraryOrigin.series);
    final mine = entry(_movie(3), origin: LibraryOrigin.manual);
    final reserve = reserveOf(
      entries: [ready, coming, series, mine],
      downloads: {
        for (final (e, s) in [
          (ready, DownloadStatus.completed),
          (coming, DownloadStatus.downloading),
          (series, DownloadStatus.completed),
          (mine, DownloadStatus.completed),
        ])
          e.downloadId: download(e, s),
      },
      history: const {},
      followed: const {},
    );
    // The series' episode counts; the viewer's own movie does not.
    expect(reserve.ready, const Duration(minutes: 90) + episodeEstimate);
    expect(reserve.pending, episodeEstimate);
    expect(reserve.picks, [ready, coming]);
  });

  test('watched smart downloads are listed to delete', () {
    final movie = entry(_movie(1));
    final seen = entry(_episode(1));
    final next = entry(_episode(2));
    final series = entry(_episode(1), origin: LibraryOrigin.series);
    final reserve = reserveOf(
      entries: [movie, seen, next, series],
      downloads: const {},
      history: {
        'tt1': WatchEntry.of(
          movie.item,
          position: const Duration(minutes: 89),
          duration: const Duration(minutes: 90),
        ),
      },
      followed: {_series.id: following(_series, episode: 1)},
    );
    expect(reserve.watched, [movie, seen]);
    expect(reserve.ready, episodeEstimate);
  });

  test('what is left of a started item counts', () {
    final movie = entry(_movie(1));
    final reserve = reserveOf(
      entries: [movie],
      downloads: const {},
      history: {
        'tt1': WatchEntry.of(
          movie.item,
          position: const Duration(minutes: 30),
          duration: const Duration(minutes: 90),
        ),
      },
      followed: const {},
    );
    expect(reserve.ready, const Duration(minutes: 60));
  });

  test('failed smart downloads are listed to replace', () {
    final failed = entry(_movie(1), onDisk: false);
    final reserve = reserveOf(
      entries: [failed],
      downloads: {failed.downloadId: download(failed, DownloadStatus.failed)},
      history: const {},
      followed: const {},
    );
    expect(reserve.failed, [failed]);
    expect(reserve.planned, Duration.zero);
  });

  test('origins and reasons survive a save', () {
    final smart = LibraryEntry.fromJson(
      LibraryEntry(
        item: _movie(1),
        downloadId: 'd',
        release: fakeRelease(1),
        fileIndex: 0,
        path: '/x',
        addedAt: DateTime(2026),
        origin: LibraryOrigin.smart,
        reason: 'Next episode',
      ).toJson(),
    )!;
    expect(smart.origin, LibraryOrigin.smart);
    expect(smart.reason, 'Next episode');
    final legacy = LibraryEntry.fromJson(
      {...smart.toJson()}
        ..remove('origin')
        ..['automatic'] = true,
    )!;
    expect(legacy.origin, LibraryOrigin.series);
    expect(smart.owned(LibraryOrigin.manual).reason, isNull);
  });
}
