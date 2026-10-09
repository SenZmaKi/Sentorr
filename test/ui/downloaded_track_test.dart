import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/stream/stream_status.dart';
import 'package:sentorr/ui/pages/player/seek_track.dart';
import 'package:sentorr/ui/pages/player/downloaded_track.dart';
import 'package:sentorr/ui/shared/theme/player_colors.dart';
import 'package:torrent_stream/torrent_stream.dart';

void main() {
  testWidgets(
    'both track consumers prefer indexed coverage over transient cache',
    (tester) async {
      final status = ValueNotifier<StreamStatus?>(
        const StreamStatus(stage: StreamStage.streaming),
      );
      final cached = ValueNotifier<List<({double start, double end})>>([
        (start: 0.2, end: 0.4),
      ]);
      List<({double start, double end})> shown = const [];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: DownloadedTrack(
            status: status,
            cached: cached,
            builder: (_, ranges) {
              shown = ranges;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(shown, cached.value);
      cached.value = [(start: 0.7, end: 0.9)];
      await tester.pump();
      expect(shown, cached.value);
      status.value = const StreamStatus(
        stage: StreamStage.streaming,
        transfer: TorrentStreamState(mediaDuration: 100),
      );
      await tester.pump();
      expect(
        shown,
        isEmpty,
      ); // A ready but empty index suppresses cached coverage.
      status.value = const StreamStatus(
        stage: StreamStage.streaming,
        localFile: '/film',
      );
      await tester.pump();
      expect(shown, [(start: 0.0, end: 1.0)]);
      status.value = const StreamStatus(stage: StreamStage.preparing);
      await tester.pump();
      expect(shown, isEmpty);
      await tester.pumpWidget(const SizedBox());
      status.dispose();
      cached.dispose();
    },
  );

  test('availability maps indexed timestamps without filling seek gaps', () {
    const status = StreamStatus(
      stage: StreamStage.streaming,
      transfer: TorrentStreamState(
        selectedFile: TorrentStreamFile(
          index: 0,
          path: 'video',
          length: 1000,
          isPadFile: false,
        ),
        downloadedTimes: [(start: 0, end: 20), (start: 80, end: 100)],
        mediaDuration: 100,
      ),
    );
    expect(status.downloadedSpans, [
      (start: 0.0, end: 0.2),
      (start: 0.8, end: 1.0),
    ]);
    expect(
      const StreamStatus(stage: StreamStage.preparing).downloadedSpans,
      isEmpty,
    );
    expect(
      const StreamStatus(
        stage: StreamStage.streaming,
        localFile: '/film',
      ).downloadedSpans,
      [(start: 0.0, end: 1.0)],
    );
  });
  test('fragmented maps bound paint work without filling unknown gaps', () {
    final status = StreamStatus(
      stage: StreamStage.streaming,
      transfer: TorrentStreamState(
        selectedFile: const TorrentStreamFile(
          index: 0,
          path: 'video',
          length: 10000,
          isPadFile: false,
        ),
        mediaDuration: 10000,
        downloadedTimes: [
          for (var n = 0; n < 10000; n += 2)
            (start: n.toDouble(), end: (n + 1).toDouble()),
        ],
      ),
    );
    expect(status.downloadedSpans, isEmpty);
  });
  test('partial raw byte ranges stay unknown without a container index', () {
    const status = StreamStatus(
      stage: StreamStage.streaming,
      transfer: TorrentStreamState(
        selectedFile: TorrentStreamFile(
          index: 0,
          path: 'video',
          length: 1000,
          isPadFile: false,
        ),
        selectedBytes: 100,
        downloadedRanges: [(start: 900, end: 1000)],
      ),
    );
    expect(status.downloadedSpans, isEmpty);
    expect(
      status
          .copyWith(
            transfer: const TorrentStreamState(
              selectedFile: TorrentStreamFile(
                index: 0,
                path: 'video',
                length: 1000,
                isPadFile: false,
              ),
              selectedBytes: 1000,
            ),
          )
          .downloadedSpans,
      [(start: 0.0, end: 1.0)],
    );
  });
  for (final colors in [PlayerColors.dark, PlayerColors.light]) {
    for (final flat in [false, true]) {
      testWidgets(
        'track preserves downloaded gaps (${colors.floatingBars}, $flat)',
        (tester) async {
          await tester.runAsync(() async {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            SeekTrackPainter(
              played: 0.1,
              downloaded: const [
                (start: 0.0, end: 0.3),
                (start: 0.7, end: 0.9),
              ],
              hover: null,
              active: 0,
              focused: false,
              colors: colors,
              flat: flat,
            ).paint(canvas, const Size(100, 10));
            final picture = recorder.endRecording();
            final image = await picture.toImage(100, 10);
            final bytes = (await image.toByteData())!;
            int pixel(int x) => bytes.getUint32((5 * 100 + x) * 4);
            expect(pixel(20), pixel(80));
            expect(pixel(50), isNot(pixel(20)));
            expect(pixel(50), pixel(95));
            expect(pixel(5), isNot(pixel(20)));
            image.dispose();
            picture.dispose();
          });
        },
      );
    }
  }
}
