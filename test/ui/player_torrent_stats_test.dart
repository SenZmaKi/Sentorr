import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/player/stream/stream_status.dart';
import 'package:sentorr/ui/pages/player/torrent_stats.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:torrent_stream/torrent_stream.dart';

void main() {
  testWidgets('stream progress becomes upload-only when the file completes', (
    tester,
  ) async {
    const file = TorrentStreamFile(
      index: 0,
      path: 'movie.mkv',
      length: 100,
      isPadFile: false,
    );
    final status = ValueNotifier<StreamStatus?>(
      const StreamStatus(
        stage: StreamStage.streaming,
        transfer: TorrentStreamState(selectedFile: file, selectedBytes: 50),
      ),
    );
    addTearDown(status.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: Scaffold(body: TorrentStats(status: status, compact: true)),
      ),
    );
    expect(find.text('50%'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    status.value = status.value!.copyWith(
      transfer: const TorrentStreamState(
        selectedFile: file,
        selectedBytes: 100,
        uploadBytesPerSecond: 4096,
      ),
    );
    await tester.pump();
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    expect(find.text('4.0 KB/s'), findsOneWidget);
  });

  testWidgets('downloaded playback without a torrent shows no transfer rates', (
    tester,
  ) async {
    final status = ValueNotifier<StreamStatus?>(
      const StreamStatus(stage: StreamStage.streaming, localFile: '/movie.mkv'),
    );
    addTearDown(status.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: Scaffold(body: TorrentStats(status: status)),
      ),
    );
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    expect(find.byIcon(Icons.people_outline_rounded), findsNothing);
  });

  for (final brightness in Brightness.values) {
    for (final compact in [false, true]) {
      testWidgets('local upload updates in $brightness, compact=$compact', (
        tester,
      ) async {
        final status = ValueNotifier<StreamStatus?>(
          const StreamStatus(
            stage: StreamStage.streaming,
            localFile: '/movie.mkv',
            transfer: TorrentStreamState(
              uploadBytesPerSecond: 4096,
              selectedFile: TorrentStreamFile(
                index: 0,
                path: 'movie.mkv',
                length: 100,
                isPadFile: false,
              ),
              // A local source is complete even while the queue rechecks it.
              selectedBytes: 25,
            ),
          ),
        );
        addTearDown(status.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildSentorrTheme(brightness),
            home: Scaffold(
              body: TorrentStats(status: status, compact: compact),
            ),
          ),
        );
        expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
        expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
        expect(find.text('4.0 KB/s'), findsOneWidget);
        expect(find.text('Downloaded'), findsOneWidget);
        expect(find.text('25%'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        status.value = status.value!.copyWith(
          transfer: const TorrentStreamState(
            uploadBytesPerSecond: 8192,
            selectedFile: TorrentStreamFile(
              index: 0,
              path: 'movie.mkv',
              length: 100,
              isPadFile: false,
            ),
            selectedBytes: 100,
          ),
        );
        await tester.pump();
        expect(find.text('8.0 KB/s'), findsOneWidget);
      });
    }
  }
}
