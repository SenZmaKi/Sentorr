// Dedicated development entry point. Normal app builds never auto-pair.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentorr/app/bootstrap.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/player/engine.dart';
import 'package:sentorr/player/stream/parked_stream.dart';
import 'package:sentorr/torrents/engine.dart';

import 'partial_source.dart';
import 'seed.dart';
import 'outage_check.dart';

import 'package:torrent_stream/torrent_stream.dart';

import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/queue_builder.dart';
import 'package:sentorr/player/session.dart';
import 'package:sentorr/settings/notifier.dart';
import 'package:sentorr/sync/continuity/host.dart';
import 'package:sentorr/sync/continuity/notifier.dart';
import 'package:sentorr/sync/devices.dart';
import 'package:sentorr/sync/models.dart';
import 'package:sentorr/sync/service.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/ui/components/app.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = Platform.environment;
  final role = environment['SENTORR_LAB_ROLE']!;
  final root = Directory(environment['SENTORR_LAB_ROOT']!);
  final sidecar = environment['SENTORR_LAB_SIDECAR'] == '1';
  final partial = environment['SENTORR_LAB_PARTIAL'] == '1';
  final outage = environment['SENTORR_LAB_OUTAGE'] ?? '';
  final smoke = environment['SENTORR_LAB_SMOKE'] == '1';
  final result = File('${root.path}/$role-result.json');
  AppRuntime? runtime;
  Timer? frames;
  void Function()? closeSeed;
  Future<void> Function()? independentSeed;
  try {
    if (smoke && Platform.isMacOS) {
      // Keep automated peers out of Dock activation/window restore flows.
      await const MethodChannel('sentorr/menu_bar_mode')
          .invokeMethod<bool>('setEnabled', {'enabled': true});
    }
    runtime = await AppRuntime.initialize(
      rootDirectory: Directory('${root.path}/$role'),
      configureLoginStartup: false,
    );
    final container = runtime.container;
    if (partial && role == 'Phone') {
      independentSeed = await startLabSeed(root);
      await container
          .read(torrentEngineProvider)
          .configure(
            TorrentEngineSettings(
              transport: TorrentTransport.tcpOnly,
              enableDht: false,
              enableLsd: false,
              enableUpnp: false,
              enableNatPmp: false,
              listenInterfaces: '127.0.0.1:0',
            ),
          );
    }
    await container.read(devicesProvider.notifier).rename('Lab $role');
    await container
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            streaming: s.streaming.copyWith(
              pauseOnFocusLoss: false,
              downloadAheadMinutes: partial
                  ? 1
                  : s.streaming.downloadAheadMinutes,
            ),
          ),
        );
    final service = container.read(syncServiceProvider);
    final identity = container.read(devicesProvider).identity;
    // This directory is private to a single lab run. Only public identity
    // crosses the rendezvous; each process keeps its own private key/data.
    await File('${root.path}/$role-peer.json').writeAsString(
      jsonEncode({
        'id': identity.id,
        'name': identity.name,
        'certificate': identity.certificatePem,
        'pairedAt': DateTime.now().toUtc().toIso8601String(),
        'address': {'host': '127.0.0.1', 'port': service.server.port},
      }),
    );
    final peer = File(
      '${root.path}/${role == 'MacBook' ? 'Phone' : 'MacBook'}-peer.json',
    );
    await waitFor(() => peer.existsSync());
    final paired = PairedDevice.fromJson(
      jsonDecode(await peer.readAsString()),
    )!;
    await service.addPaired(paired);
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: smoke ? const _NativePlayback() : const SentorrApp(),
      ),
    );
    if (smoke) {
      // A hidden macOS window suppresses normal scheduler frames. Explicit
      // frames keep the native Video output mounted for smoke.
      frames = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => WidgetsBinding.instance.scheduleWarmUpFrame(),
      );
    }
    await windowManager.setTitle('Sentorr · Lab $role');
    if (!smoke) {
      await runtime.window.reveal();
      await windowManager.setBounds(
        role == 'Phone'
            ? const Rect.fromLTWH(850, 80, 390, 780)
            : const Rect.fromLTWH(30, 80, 800, 600),
      );
    }
    if (role == 'MacBook') {
      final original = File(environment['SENTORR_LAB_MEDIA']!);
      final fixture = await original.copy(
        '${root.path}/MacBook/fixture.${original.path.split('.').last}',
      );
      final item = PlaybackItem(
        title: ImdbTitle(
          id: 'tt-continuity-lab',
          title: 'Continuity lab',
          runtimeSeconds: partial ? 600 : 120,
        ),
      );
      const hash = '0000000000000000000000000000000000000001';
      if (partial) {
        final source = await partialSource(
          container.read(torrentEngineProvider),
          fixture,
          item,
          Directory('${root.path}/MacBook'),
        );
        closeSeed = source.closeSeed;
        await container.read(parkedStreamsProvider).park(source.stream);
      } else {
        await container
            .read(libraryProvider.notifier)
            .add(
              LibraryEntry(
                item: item,
                downloadId: 'lab-fixture',
                release: TorrentRelease(
                  source: TorrentSourceId.pirateBay,
                  name: 'Continuity lab',
                  infoHash: hash,
                  magnet: Uri.parse('magnet:?xt=urn:btih:$hash'),
                  seeders: 0,
                  sizeBytes: await fixture.length(),
                ),
                fileIndex: 0,
                path: fixture.path,
                addedAt: DateTime.now(),
              ),
            );
      }
      container
          .read(playerSessionProvider.notifier)
          .play(
            PlayTitle(item.title),
            queue: PlayQueue(
              items: [item],
              index: 0,
              kind: QueueKind.recommendations,
            ),
            start: const Duration(seconds: 3),
          );
      if (smoke) {
        final engine = container.read(playbackEngineProvider);
        await waitFor(
          () => engine.state.playing && engine.state.position.inSeconds >= 3,
        );
        await engine.setRate(1.25);
        await engine.setVolume(37);
        final audio = engine.state.tracks.audio
            .where((t) => t.id != 'auto' && t.id != 'no')
            .lastOrNull;
        if (audio != null && !sidecar) engine.streaming.audio.choose(audio);
        final subtitle = engine.streaming.subtitles.embedded.lastOrNull;
        if (subtitle != null) engine.streaming.subtitles.chooseTrack(subtitle);
        if (sidecar) {
          final captions = await File('${root.path}/MacBook/selected.srt')
              .writeAsString(
                '1\n00:00:00,000 --> 00:00:30,000\nContinuity caption\n',
              );
          engine.streaming.subtitles.chooseTrack(
            SubtitleTrack.uri(captions.path, title: 'External English'),
          );
        }
        await File('${root.path}/source-ready').writeAsString('ready');
        await waitFor(
          () =>
              container.read(continuityHostProvider).destination.value != null,
        );
        final position = engine.state.position;
        await Future<void>.delayed(const Duration(seconds: 2));
        if (engine.state.playing ||
            (engine.state.position - position).abs().inMilliseconds > 250) {
          throw StateError('Source did not remain paused after handoff');
        }
        await result.writeAsString(
          jsonEncode({
            'ok': true,
            'pausedAtMs': position.inMilliseconds,
            'destination': container
                .read(continuityHostProvider)
                .destination
                .value,
          }),
        );
        // Continue serving until the receiver has verified real playback.
        await waitFor(
          () => File('${root.path}/Phone-result.json').existsSync(),
        );
      }
    } else if (smoke) {
      await waitFor(() => File('${root.path}/source-ready').existsSync());
      final subscription = container.listen(
        continuityOffersProvider,
        (_, _) {},
      );
      await waitFor(() => container.read(continuityOffersProvider).isNotEmpty);
      final offer = container.read(continuityOffersProvider).single;
      if (!offer.session.playing) {
        throw StateError('Source was not playing before transfer');
      }
      final clock = Stopwatch()..start();
      await container.read(continuityTransferProvider.notifier).take(offer);
      final transfer = container.read(continuityTransferProvider);
      if (transfer.hasError) throw StateError('${transfer.error}');
      final engine = container.read(playbackEngineProvider);
      final start = engine.state.position;
      if ((engine.state.rate - 1.25).abs() > 0.01 ||
          (engine.state.volume - 37).abs() > 0.01) {
        throw StateError('Playback settings were not transferred');
      }
      if (container.read(torrentEngineProvider).torrents.isNotEmpty) {
        throw StateError('Receiver started a local torrent');
      }
      if (partial && !offer.session.buffered) {
        throw StateError('Expected a partial stream offer');
      }
      if (partial &&
          offer.session.media.bufferedBytes! >= offer.session.media.size) {
        throw StateError('Fixture finished before the partial handoff');
      }
      await waitFor(
        () =>
            engine.state.playing &&
            engine.state.position > start + const Duration(seconds: 1) &&
            (engine.state.width ?? 0) > 0,
      );
      final intent = offer.session.settings?.item;
      final audio = engine.state.track.audio;
      if (intent?.audio != null &&
          !intent!.audio!.matches(audio.id, audio.title, audio.language)) {
        throw StateError('Audio selection did not transfer');
      }
      if (intent?.captionsEnabled != engine.streaming.subtitles.enabled) {
        throw StateError('Caption visibility did not transfer');
      }
      final captions = engine.streaming.subtitles.embeddedTrack;
      if (intent?.subtitle != null &&
          intent!.subtitle!.file == false &&
          (captions == null ||
              !intent.subtitle!.matches(
                captions.id,
                captions.title,
                captions.language,
              ))) {
        throw StateError('Subtitle selection did not transfer');
      }
      if (sidecar &&
          (captions?.data != true ||
              !captions!.id.contains('Continuity caption'))) {
        throw StateError('External captions were not transferred');
      }
      await waitFor(
        () => File('${root.path}/MacBook-result.json').existsSync(),
      );
      final source = jsonDecode(
        await File('${root.path}/MacBook-result.json').readAsString(),
      ) as Map;
      final drift =
          (engine.state.position.inMilliseconds - (source['pausedAtMs'] as int))
              .abs();
      if (drift > 6000) {
        throw StateError('Resume position drifted by $drift ms');
      }
      final recovery = outage.isEmpty
          ? <String, Object?>{}
          : await checkOutage(container, root, outage);
      await result.writeAsString(
        jsonEncode({
          ...recovery,
          'ok': true,
          'handoffMs': clock.elapsedMilliseconds,
          'positionMs': engine.state.position.inMilliseconds,
          'width': engine.state.width,
          'rate': engine.state.rate,
          'audio': audio.id,
          'subtitle': captions?.data == true ? 'external-data' : captions?.id,
          'captionsEnabled': engine.streaming.subtitles.enabled,
          'volume': engine.state.volume,
          'receiverTorrents': container
              .read(torrentEngineProvider)
              .torrents
              .length,
          'partial': partial,
          'sourceBufferedBytes': offer.session.media.bufferedBytes,
          'sourceSize': offer.session.media.size,
          'peer': engine.streaming.status.value?.peer,
          'sourcePausedAtMs': source['pausedAtMs'],
        }),
      );
      subscription.close();
    }
    if (smoke) {
      frames?.cancel();
      await runtime.dispose();
      closeSeed?.call();
      await independentSeed?.call();
      exit(0);
    }
  } catch (error, stack) {
    await result.writeAsString(
      jsonEncode({'ok': false, 'error': '$error', 'stack': '$stack'}),
    );
    frames?.cancel();
    await runtime?.dispose();
    closeSeed?.call();
    await independentSeed?.call();
    exit(1);
  }
}

Future<void> waitFor(bool Function() ready) async {
  final clock = Stopwatch()..start();
  while (!ready()) {
    if (clock.elapsed > const Duration(seconds: 60)) {
      throw TimeoutException('Lab timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

// Keep native outputs mounted from the first warm-up frame. Hidden macOS
// windows cannot drive the full app's route/AnimatedSwitcher transitions.
// Interactive mode above uses the unmodified SentorrApp and PlayerHost.
class _NativePlayback extends ConsumerWidget {
  const _NativePlayback();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(playbackEngineProvider);
    return MaterialApp(
      home: Scaffold(
        body: Video(controller: engine.video, controls: NoVideoControls),
      ),
    );
  }
}
