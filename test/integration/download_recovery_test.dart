import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:dio/io.dart';
import 'package:logging/logging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:media_kit/media_kit.dart';
import 'package:torrent_stream/torrent_stream.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/library/playback.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/torrent_playback.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/net/net.dart';
import 'package:sentorr/shared/net/online.dart';
import 'package:sentorr/shared/persistence/app_paths.dart';
import 'package:sentorr/torrents/engine.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/ui/pages/player/recover_download.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';
import 'package:sentorr/ui/shared/verify_download.dart';

import '../../packages/torrent_stream/test/engine_support.dart' as native;
import '../support/fake_library.dart';
import '../support/native_video.dart';

class _RealHttp extends HttpOverrides {}

// Real UI, HTTP metadata, libtorrent queue/seed, disk hashing, and MediaKit.
// Only catalog/settings persistence and the internet probe are isolated.
void main() {
  const mpv =
      'build/macos/Build/Products/Debug/Sentorr.app/Contents/Frameworks/Mpv.framework/Mpv';
  testWidgets(
    'damaged playback verifies, recovers, resumes, and manually verifies',
    (tester) async {
      late Directory root;
      late ProviderContainer container;
      late TorrentEngine engine;
      late TorrentPlayback playback;
      late Player player;
      late HttpServer server;
      late void Function() closeSeed;
      late StreamSubscription<Object?> connections;
      late NetworkClient network;
      late Uint8List original;
      late File target;
      late PlaybackItem item;
      var metadataRequests = 0, resumed = 0;
      final errors = <String>[];
      StreamSubscription<String>? errorSub;
      StreamSubscription<LogRecord>? logs;
      await tester.runAsync(() async {
        Logger.root.level = Level.ALL;
        logs = Logger.root.onRecord.listen((r) {
          if (r.loggerName.contains('integrity') ||
              r.loggerName.contains('metadata') ||
              r.loggerName.contains('downloads') ||
              r.loggerName.contains('player.stream')) {
            print('${r.loggerName}: ${r.message} ${r.error ?? ''}');
          }
        });
        root = await Directory.systemTemp.createTemp('sentorr-recovery-e2e-');
        initializeBundledVideo(mpv);
        final seedFile = File('${root.path}/seed/fixture.mp4');
        await seedFile.parent.create(recursive: true);
        final encode = await Process.run('ffmpeg', [
          '-v',
          'error',
          '-f',
          'lavfi',
          '-i',
          'testsrc2=size=320x180:rate=24:duration=8',
          '-c:v',
          'libx264',
          '-preset',
          'ultrafast',
          '-movflags',
          '+faststart',
          seedFile.path,
        ]);
        expect(encode.exitCode, 0, reason: '${encode.stderr}');
        original = await seedFile.readAsBytes();
        final (metadata, peer, stop) = await native.seedFile(
          seedFile,
          pieceSize: 16384,
        );
        closeSeed = stop;
        final torrent = await File('${root.path}/fixture.torrent')
            .writeAsBytes(metadata);
        final hash = loadTorrentFile(torrent.path).infohashHex;
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((r) async {
          metadataRequests++;
          r.response.add(metadata);
          await r.response.close();
        });
        final release = TorrentRelease(
          source: TorrentSourceId.bitsearch,
          name: 'Fixture',
          infoHash: hash,
          magnet: Uri.parse('magnet:?xt=urn:btih:$hash'),
          torrentUrls: [
            Uri.parse('http://127.0.0.1:${server.port}/fixture.torrent'),
          ],
          seeders: 1,
          sizeBytes: original.length,
        );
        item = PlaybackItem(
          title: ImdbTitle(id: 'tt900', title: 'Recovery fixture'),
        );
        target = File('${root.path}/downloads/movie.mp4');
        await target.parent.create(recursive: true);
        final damaged = Uint8List.fromList(original);
        damaged.fillRange(0, 16384, 0);
        damaged.fillRange(32768, 49152, 0);
        damaged.fillRange(damaged.length - 16384, damaged.length, 0);
        await target.writeAsBytes(damaged);
        final entry = LibraryEntry(
          item: item,
          downloadId: 'copy:peer:fixture',
          release: release,
          fileIndex: 0,
          path: target.path,
          addedAt: DateTime.now(),
        );
        engine = native.loopbackEngine();
        final connected = <String>{};
        connections = engine.states.listen((all) {
          for (final t in all) {
            if (connected.add(t.infoHash)) {
              unawaited(engine.addPeers(t.infoHash, [peer]));
            }
          }
        });
        network = NetworkClient(http2: false, logging: false);
        network.dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () => HttpOverrides.runWithHttpOverrides(
            () => HttpClient(),
            _RealHttp(),
          ),
        );
        container = ProviderContainer(
          overrides: [
            appPathsProvider.overrideWithValue(
              await AppPaths.initialize(rootDirectory: root),
            ),
            initialSettingsProvider.overrideWithValue(const AppSettings()),
            networkClientProvider.overrideWithValue(network),
            internetProbeProvider.overrideWithValue(() async => true),
            torrentEngineProvider.overrideWithValue(engine),
            ...libraryOverrides([entry]),
          ],
        );
        await container
            .read(downloadQueueProvider)
            .initialize(
              const DownloadSettings(seedingMode: SeedingMode.disabled),
            );
        container.listen(downloadsProvider, (_, _) {});
        player = Player(
          configuration: const PlayerConfiguration(logLevel: MPVLogLevel.error),
        );
        await (player.platform as NativePlayer).setProperty('vo', 'null');
        await (player.platform as NativePlayer).setProperty('vid', 'auto');
        await (player.platform as NativePlayer).setProperty('ao', 'null');
        errorSub = player.stream.error.listen(errors.add);
        final lookup = Provider(
          (ref) =>
              () => offlineSourceFor(ref, item),
        );
        playback = TorrentPlayback(
          player: player,
          engine: engine,
          configFor: (_) async =>
              TorrentStreamConfig(cacheDirectory: '${root.path}/cache'),
          find: (_, _) async => throw StateError('Unexpected torrent search'),
          outputReady: () async {},
          fetchMetadata: (_, _) async => metadata,
          offline: (_) => container.read(lookup)(),
        );
      });
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: buildSentorrTheme(Brightness.dark),
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    final entry = ref.watch(libraryProvider).single;
                    return ValueListenableBuilder(
                      valueListenable: playback.status,
                      builder: (context, status, _) =>
                          status?.stage == StreamStage.failed
                          ? LocalPlaybackProblem(
                              key: ValueKey((entry.id, entry.path)),
                              entry: entry,
                              onReady: () {
                                resumed++;
                                unawaited(
                                  playback.play(
                                    item,
                                    start: const Duration(seconds: 3),
                                  ),
                                );
                              },
                              onBack: () {},
                              chooseLabel: 'Search for torrents',
                            )
                          : TextButton(
                              onPressed: () => verifyDownload(context, entry),
                              child: const Text('Manual check'),
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        Future<void> waitFor(bool Function() ready, String step) async {
          final timer = Stopwatch()..start();
          var turns = 0;
          while (!ready()) {
            if (++turns % 100 == 0) {
              print(
                'WAIT $step stage=${playback.status.value?.stage} position=${player.state.position} width=${player.state.width}',
              );
            }
            if (timer.elapsed > const Duration(seconds: 45)) {
              fail(
                'Timed out: $step; metadata=$metadataRequests; stage=${playback.status.value?.stage}; text=${find.byType(Text).evaluate().map((e) => (e.widget as Text).data)}; errors=$errors; downloads=${container.read(downloadQueueProvider).items.map((d) => '${d.status}: ${d.error}')}',
              );
            }
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(milliseconds: 50));
          }
          print('PASS $step');
        }

        await tester.runAsync(() async {
          unawaited(playback.play(item));
        });
        await waitFor(
          () => find.text('Recover missing pieces').evaluate().isNotEmpty,
          'automatic verification after native decoder failure',
        );
        expect(
          errors,
          isNotEmpty,
          reason: 'real native playback must reject corrupted file',
        );
        expect(metadataRequests, 1);
        await tester.tap(find.text('Recover missing pieces'));
        await waitFor(
          () => resumed == 1,
          'recovery UI callback after replacement',
        );
        await waitFor(
          () =>
              container.read(downloadQueueProvider).items.single.status ==
              DownloadStatus.completed,
          'native download repairs and validates file',
        );
        await waitFor(
          () =>
              player.state.position > const Duration(seconds: 3) &&
              player.state.width != null,
          'decoded resumed playback progresses',
        );
        expect(await tester.runAsync(target.readAsBytes), original);
        expect(playback.status.value?.stage, StreamStage.streaming);
        expect(find.text('Recover missing pieces'), findsNothing);
        expect(resumed, 1);
        await tester.tap(find.text('Manual check'));
        await waitFor(
          () => find
              .textContaining('No missing or damaged pieces found')
              .evaluate()
              .isNotEmpty,
          'manual full verification',
        );
        expect(find.text('Recover missing pieces'), findsNothing);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        print(
          'E2E PASS: decoder rejected damage, automatic verification, HTTP metadata, '
          'UI recovery, native queue, exact bytes, resumed decode at 3s, manual verification',
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        var closed = false;
        Object? shutdownError;
        await tester.runAsync(() async {
          unawaited(
            () async {
                  await playback.close();
                  playback.dispose();
                  await player.dispose();
                  await errorSub?.cancel();
                  await logs?.cancel();
                  await container.read(downloadQueueProvider).dispose();
                  container.dispose();
                  await connections.cancel();
                  await engine.close();
                  closeSeed();
                  await server.close(force: true);
                  network.dio.close(force: true);
                  await root.delete(recursive: true);
                }()
                .catchError((Object e) {
                  shutdownError = e;
                })
                .whenComplete(() => closed = true),
          );
        });
        final cleanupClock = Stopwatch()..start();
        while (!closed && cleanupClock.elapsed < const Duration(seconds: 15)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(closed, isTrue, reason: 'native teardown must finish');
        expect(shutdownError, isNull);
      }
    },
    skip: !Platform.isMacOS || !File(mpv).existsSync(),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
