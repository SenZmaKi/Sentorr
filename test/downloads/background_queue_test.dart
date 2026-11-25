import 'dart:io';

import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:test/test.dart';

import '../support/fake_download_torrents.dart';

Future<void> settle() async {
  for (var n = 0; n < 30; n++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Directory root;
  late FakeTorrents torrents;
  late DownloadQueue queue;

  Future<String> enqueue(String title, {bool background = false}) async {
    final id = await queue.enqueue(
      TorrentDownloadJob(
        title: title,
        magnet: Uri.parse('magnet:?xt=urn:btih:$title&dn=$title'),
        destinationDirectory: root.path,
        selectedFileIndices: [1],
        background: background,
      ),
    );
    await settle();
    return id;
  }

  Map<String, DownloadStatus> statuses() => {
    for (final i in queue.items) i.job.title: i.status,
  };

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-background-test-');
    torrents = FakeTorrents();
    queue = DownloadQueue(
      torrents,
      DownloadRepository(JsonFileStore(File('${root.path}/queue.json'))),
    );
    await queue.initialize(
      const DownloadSettings(
        maxActiveDownloads: 3,
        seedingMode: SeedingMode.disabled,
      ),
    );
  });
  tearDown(() async {
    await queue.dispose();
    await root.delete(recursive: true);
  });

  test('background downloads run one at a time', () async {
    await enqueue('a', background: true);
    await enqueue('b', background: true);
    await queue.tick();
    expect(statuses(), {
      'a': DownloadStatus.downloading,
      'b': DownloadStatus.queued,
    });
    expect(torrents.running('b'), isFalse);
  });

  test('background downloads wait for the viewer\'s own', () async {
    await enqueue('smart', background: true);
    await queue.tick();
    expect(statuses()['smart'], DownloadStatus.downloading);
    await enqueue('mine');
    await queue.tick();
    expect(statuses(), {
      'smart': DownloadStatus.queued,
      'mine': DownloadStatus.downloading,
    });
    expect(torrents.running('smart'), isFalse);
    torrents['mine'].done = 100;
    await queue.tick();
    await queue.tick();
    expect(statuses(), {
      'smart': DownloadStatus.downloading,
      'mine': DownloadStatus.completed,
    });
  });

  test('a paused download of the viewer\'s does not hold them', () async {
    final mine = await enqueue('mine');
    await queue.pause(mine);
    await enqueue('smart', background: true);
    await queue.tick();
    expect(statuses()['smart'], DownloadStatus.downloading);
  });

  test('a hold stops background downloads until released', () async {
    await enqueue('smart', background: true);
    await enqueue('mine');
    await queue.holdBackground('mobileData');
    final mine = queue.items.firstWhere((i) => i.job.title == 'mine');
    await queue.pause(mine.id);
    await queue.tick();
    expect(statuses()['smart'], DownloadStatus.queued);
    expect(queue.backgroundHold, 'mobileData');
    await queue.holdBackground(null);
    await queue.tick();
    expect(statuses()['smart'], DownloadStatus.downloading);
  });

  test('the background flag survives a restart', () {
    final job = TorrentDownloadJob(
      title: 'x',
      magnet: Uri.parse('magnet:?xt=urn:btih:x'),
      destinationDirectory: '/d',
      background: true,
    );
    expect(TorrentDownloadJob.fromJson(job.toJson()).background, isTrue);
    expect(
      TorrentDownloadJob.fromJson({...job.toJson()}..remove('background'))
          .background,
      isFalse,
    );
  });

  test('a promoted download is the viewer\'s own', () async {
    final smart = await enqueue('smart', background: true);
    await queue.holdBackground('playback');
    await queue.tick();
    expect(statuses()['smart'], DownloadStatus.queued);
    await queue.promote(smart);
    await queue.tick();
    expect(statuses()['smart'], DownloadStatus.downloading);
    expect(queue.items.single.job.background, isFalse);
  });
}
