import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/sync/payload.dart';
import 'package:sentorr/sync/peers.dart';

import '../support/fake_imdb.dart';
import '../support/fake_torrents.dart';
import 'harness.dart';

final _series = fakeTitle(2, series: true);
final _episode = PlaybackItem(
  title: ImdbTitle(id: 'tt101', title: 'Episode 1'),
  series: _series,
  season: 1,
  episode: 1,
);

final _entry = LibraryEntry(
  item: _episode,
  downloadId: 'd1',
  release: fakeRelease(1),
  fileIndex: 0,
  path: '/nowhere/E1.mkv',
  addedAt: DateTime(2026),
);

DownloadItem _halfway(DownloadStatus status) => DownloadItem(
  id: 'd1',
  job: TorrentDownloadJob(
    title: 'E1',
    magnet: Uri.parse('magnet:?xt=urn:btih:d1'),
    destinationDirectory: '/nowhere',
  ),
  status: status,
  files: [DownloadFileProgress(0, 'E1.mkv', 1000, 500)],
);

void main() {
  test('buffered stream offers stay separate from copyable media and revision ignores progress', () {
    PeerMedia offer(int bytes) => PeerMedia(
      item: _entry.item,
      size: 1000,
      name: 'E1.mkv',
      release: _entry.release,
      fileIndex: 0,
      bufferedBytes: bytes,
    );
    final first = PeerLibrary(streams: [offer(100)]).toJson();
    final next = PeerLibrary(streams: [offer(200)]).toJson();
    expect(first['revision'], next['revision']);
    final decoded = PeerLibrary.fromJson(next);
    expect(decoded.media, isEmpty);
    expect(decoded.streams.single.bufferedBytes, 200);
    expect(
      PeerLibrary.fromJson(PeerLibrary(streams: [offer(1001)]).toJson())
          .streams,
      isEmpty,
    );
  });

  test('a library round-trips its downloads under way', () {
    final library = PeerLibrary(
      downloads: [
        PeerDownload(
          item: PlaybackItem(
            title: ImdbTitle(id: 'tt1', title: 'Movie'),
          ),
          transfer: PeerTransfer.paused,
          progress: 0.25,
          size: 4096,
        ),
      ],
    );
    final back = PeerLibrary.fromJson(library.toJson());
    final d = back.downloads.single;
    expect(d.id, 'tt1');
    expect(d.transfer, PeerTransfer.paused);
    expect(d.progress, 0.25);
    expect(d.size, 4096);
    // Devices from before downloads were shared send media alone.
    expect(PeerLibrary.fromJson({'media': []}).downloads, isEmpty);
    expect(
      PeerLibrary.fromJson({
        'downloads': [
          {'transfer': 'x'},
        ],
      }).downloads,
      isEmpty,
    );
  });

  test('a sync carries both devices\' downloads under way', () async {
    final laptop = await syncDevice(
      'Laptop',
      library: [_entry],
      downloads: [_halfway(DownloadStatus.downloading)],
    );
    // The app's screens keep the queue's downloads loaded.
    laptop.listen(downloadsProvider, (_, _) {});
    await laptop.read(downloadsProvider.future);
    final phone = await syncDevice('Phone');
    await pair(laptop, phone);

    // The laptop calls; the phone learns its library from the call alone.
    await laptop.read(peersProvider.notifier).syncWith(idOf(phone));
    final heard = phone.read(peersProvider)[idOf(laptop)]!;
    expect(heard.online, true);
    final d = heard.downloads.single;
    expect(d.id, _episode.id);
    expect(d.transfer, PeerTransfer.downloading);
    expect(d.progress, 0.5);
    expect(d.size, 1000);
    expect(heard.media, isEmpty);

    // And the answer tells the laptop the phone has nothing.
    final answered = laptop.read(peersProvider)[idOf(phone)]!;
    expect(answered.online, true);
    expect(answered.downloads, isEmpty);
  });
}
