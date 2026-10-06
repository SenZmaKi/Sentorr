import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/progress_summary.dart';
import 'package:test/test.dart';

DownloadItem item(
  String id,
  DownloadStatus status, {
  int done = 0,
  int size = 0,
  double speed = 0,
}) => DownloadItem(
  id: id,
  job: TorrentDownloadJob(
    title: 'Title $id',
    magnet: Uri.parse('magnet:?xt=urn:btih:$id'),
    destinationDirectory: '/tmp',
  ),
  status: status,
  downloadBytesPerSecond: speed,
  files: [if (size > 0) DownloadFileProgress(0, 'f', size, done)],
);

void main() {
  test('nothing to show without active or held downloads', () {
    expect(DownloadProgressSummary.of([]), isNull);
    expect(
      DownloadProgressSummary.of([
        item('a', DownloadStatus.completed, done: 10, size: 10),
        item('b', DownloadStatus.paused, done: 1, size: 10),
      ]),
      isNull,
    );
  });

  test('a single download is shown by title', () {
    final s = DownloadProgressSummary.of([
      item('a', DownloadStatus.downloading, done: 25, size: 100, speed: 2048),
    ])!;
    expect(s.title, 'Title a');
    expect(s.text, '25% · 2.0 KB/s');
    expect(s.progress, 0.25);
    expect(s.paused, isFalse);
  });

  test('several downloads combine bytes and count waiting and seeding', () {
    final s = DownloadProgressSummary.of([
      item('a', DownloadStatus.downloading, done: 50, size: 100),
      item('b', DownloadStatus.queued, done: 0, size: 300),
      item('c', DownloadStatus.seeding, done: 10, size: 10),
    ])!;
    expect(s.title, 'Downloading 2 titles');
    expect(s.text, '12% · 0 B/s · 1 queued · 1 seeding');
    expect(s.progress, 50 / 400);
  });

  test('unknown sizes are preparing', () {
    final s = DownloadProgressSummary.of([
      item('a', DownloadStatus.preparing),
    ])!;
    expect(s.preparing, isTrue);
    expect(s.progress, isNull);
  });

  test('seeding alone is done downloading', () {
    expect(
      DownloadProgressSummary.of([
        item('a', DownloadStatus.seeding, done: 10, size: 10),
      ]),
      isNull,
    );
  });

  test('waiting and paused shares do not count as downloading', () {
    for (final status in [
      DownloadStatus.queued,
      DownloadStatus.preparing,
      DownloadStatus.paused,
    ]) {
      final finished = item('a', status, done: 10, size: 10);
      expect(DownloadProgressSummary.of([finished], held: {'a'}), isNull);
      final s = DownloadProgressSummary.of([
        finished,
        item('b', DownloadStatus.downloading, done: 25, size: 100),
      ])!;
      expect(s.title, 'Title b');
      expect(s.progress, .25);
    }
  });

  test('held paused downloads offer resume once nothing runs', () {
    final items = [
      item('a', DownloadStatus.paused, done: 30, size: 100),
      item('b', DownloadStatus.paused, done: 10, size: 100),
    ];
    final s = DownloadProgressSummary.of(items, held: {'a', 'b'})!;
    expect(s.paused, isTrue);
    expect(s.title, 'Paused 2 titles');
    expect(s.progress, 0.2);
  });
}
