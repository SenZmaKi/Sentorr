import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/preview/availability.dart';
import 'package:sentorr/player/stream/stream_status.dart';
import 'package:torrent_stream/torrent_stream.dart';

void main() {
  test('distinguishes unknown timelines from missing indexed regions', () {
    expect(previewAvailableAt(null, const Duration(seconds: 5)), isNull);
    expect(
      previewAvailableAt(
        const StreamStatus(stage: StreamStage.streaming),
        const Duration(seconds: 5),
      ),
      isNull,
    );
    const indexed = StreamStatus(
      stage: StreamStage.streaming,
      transfer: TorrentStreamState(
        mediaDuration: 100,
        downloadedTimes: [(start: 1.001, end: 1.003), (start: 10.0, end: 20.0)],
      ),
    );
    expect(previewAvailableAt(indexed, const Duration(seconds: 15)), isTrue);
    expect(previewAvailableAt(indexed, const Duration(seconds: 25)), isFalse);
    expect(previewAvailableAt(indexed, const Duration(seconds: 20)), isFalse);
    expect(
      previewAvailableAt(indexed, const Duration(milliseconds: 1002)),
      isTrue,
    );
    expect(
      previewAvailableAt(
        const StreamStatus(
          stage: StreamStage.streaming,
          localFile: '/video.mkv',
        ),
        const Duration(seconds: 50),
      ),
      isTrue,
    );
  });
}
