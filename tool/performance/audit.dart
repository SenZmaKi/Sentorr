// A hidden native app using production bootstrap, screens, queue and engine.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:torrent_stream/torrent_stream.dart';
import 'package:sentorr/app/bootstrap.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/home/catalog_rows.dart';
import 'package:sentorr/player/stream/media_kit_adapter.dart';
import 'package:sentorr/search/notifier.dart';
import 'package:sentorr/torrents/engine.dart';
import 'package:sentorr/ui/components/app.dart';
import 'package:sentorr/ui/pages/home/home_page.dart';
import 'package:sentorr/ui/components/app_shell.dart';
import 'package:sentorr/ui/shared/title_route.dart';
import 'package:sentorr/ui/shared/app_activity.dart';

final root = Platform.environment['SENTORR_AUDIT_ROOT']!;
String phase = 'startup';
final ticking = ValueNotifier(true);
Widget app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: ValueListenableBuilder<bool>(
    valueListenable: ticking,
    child: const SentorrApp(),
    builder: (_, enabled, child) => TickerMode(enabled: enabled, child: child!),
  ),
);
void emit(Map<String, Object?> data) => print('AUDIT ${jsonEncode(data)}');
Future<void> dwell(String name, int seconds) async {
  phase = name;
  emit({
    'phase': phase,
    'event': 'begin',
    'time': DateTime.now().toIso8601String(),
  });
  await Future<void>.delayed(Duration(seconds: seconds));
}

Future<void> waitFor(bool Function() done) async {
  final clock = Stopwatch()..start();
  while (!done()) {
    if (clock.elapsed.inSeconds > 60) throw StateError('Timed out in $phase');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<void> shutdown(AppRuntime runtime) async {
  phase = 'shutdown';
  emit({'phase': phase, 'event': 'begin'});
  try {
    await runtime.dispose().timeout(const Duration(seconds: 15));
  } on TimeoutException {
    emit({'event': 'shutdown_timeout', 'seconds': 15});
    exit(2);
  }
}

Future<void> main() async {
  emit({'pid': pid, 'event': 'start'});
  final runtime = await AppRuntime.initialize(
    rootDirectory: Directory('$root/data'),
  );
  final container = runtime.container;
  final engine = container.read(torrentEngineProvider);
  await engine.configure(
    TorrentEngineSettings(
      downloadBytesPerSecond: 2 * 1024 * 1024,
      transport: TorrentTransport.tcpOnly,
      enableDht: false,
      enableLsd: false,
      enableUpnp: false,
      enableNatPmp: false,
      listenInterfaces: '127.0.0.1:0',
    ),
  );
  final timer = Timer.periodic(const Duration(seconds: 1), (_) {
    final images = PaintingBinding.instance.imageCache;
    emit({
      'phase': phase,
      'time': DateTime.now().toIso8601String(),
      'uiActive': container.read(appVisibleProvider),
      'rss': ProcessInfo.currentRss,
      'maxRss': ProcessInfo.maxRss,
      'imagesBytes': images.currentSizeBytes,
      'images': images.currentSize,
      'liveImages': images.liveImageCount,
      'torrents': [
        for (final t in engine.torrents)
          {
            'received': t.receivedBytes,
            'verified': t.verifiedBytes,
            'rate': t.downloadBytesPerSecond,
            'streams': [
              for (final s in t.streams)
                {
                  'cache': s.cachedBytes,
                  'served': s.servedBytes,
                  'requests': s.requests,
                },
            ],
          },
      ],
    });
  });
  try {
    runApp(app(container));
    await dwell('home_cold', 35);
    emit({
      'event': 'catalog',
      'items': container.read(featuredTitlesProvider).value?.length,
    });
    await dwell('home_idle', 20);
    if (Platform.environment['SENTORR_AUDIT_STATIC'] == '1') {
      ticking.value = false;
      await dwell('home_tickers_disabled', 20);
      ticking.value = true;
      await dwell('home_tickers_resumed', 20);
      runApp(const MaterialApp(home: SizedBox.shrink()));
      await dwell('blank_ui', 20);
      timer.cancel();
      emit({'event': 'complete'});
      await shutdown(runtime);
      exit(0);
    }
    phase = 'home_scroll';
    emit({'phase': phase, 'event': 'begin'});
    for (var n = 0; n < 12; n++) {
      void visit(Element element) {
        if (element is StatefulElement &&
            element.state is ScrollableState &&
            element.findAncestorWidgetOfExactType<HomePage>() != null) {
          final state = element.state as ScrollableState;
          if (state.widget.axisDirection == AxisDirection.down &&
              state.position.hasContentDimensions) {
            state.position.jumpTo(
              (state.position.pixels + 450).clamp(
                0,
                state.position.maxScrollExtent,
              ),
            );
          }
        }
        element.visitChildren(visit);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(visit);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    container.read(appDestinationProvider.notifier).go(AppDestination.search);
    final search = container.read(searchProvider.notifier);
    for (final term in ['Batman', 'Severance', 'Interstellar']) {
      phase = 'search';
      search.setTerm(term);
      await Future<void>.delayed(const Duration(seconds: 1));
      await waitFor(() => !container.read(searchProvider).results.loading);
      final r = container.read(searchProvider).results;
      emit({
        'event': 'search',
        'term': term,
        'items': r.items.length,
        'error': r.error?.toString(),
      });
      if (r.items.isNotEmpty) {
        container.read(titleRoutesProvider.notifier).open(r.items.first);
        await dwell('title_details', 8);
        container.read(titleRoutesProvider.notifier).closeAll();
      }
    }
    search.setTerm('Batman');
    await Future<void>.delayed(const Duration(seconds: 1));
    await waitFor(() => !container.read(searchProvider).results.loading);
    phase = 'search_pagination';
    search.loadMore();
    await dwell('search_pagination', 12);
    emit({
      'event': 'pagination',
      'items': container.read(searchProvider).results.items.length,
    });
    container
        .read(appDestinationProvider.notifier)
        .go(AppDestination.downloads);
    final seed =
        jsonDecode(await File('$root/seed.json').readAsString()) as Map;
    final metadata = base64Decode(seed['torrent'] as String);
    final peers = [TorrentPeer('127.0.0.1', seed['port'] as int)];
    final queue = container.read(downloadQueueProvider);
    phase = 'download_start';
    final id = await queue.enqueue(
      TorrentDownloadJob(
        title: 'Performance fixture',
        destinationDirectory: '$root/download',
        torrentData: metadata,
      ),
    );
    await waitFor(
      () => queue.items.any((i) => i.id == id && i.infoHash != null),
    );
    final hash = queue.items.firstWhere((i) => i.id == id).infoHash!;
    await engine.addPeers(hash, peers);
    await dwell('download', 25);
    await queue.pause(id);
    await dwell('download_paused', 10);
    await queue.cancel(id);
    // Fresh disk path ensures streaming actually transfers from the peer.
    final player = Player(
      configuration: const PlayerConfiguration(bufferSize: 64 * 1024 * 1024),
    );
    final video = VideoController(player);
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Video(controller: video, controls: NoVideoControls),
        ),
      ),
    );
    await video.platform.future.timeout(const Duration(seconds: 20));
    final session = TorrentStreamSession(
      engine: engine,
      config: TorrentStreamConfig(cacheDirectory: '$root/stream'),
    );
    phase = 'stream_start';
    final files = await session.open(
      TorrentSource.metadata(metadata),
      peers: peers,
    );
    final stream = await session.prepareFile(files.first.index);
    final adapter = MediaKitTorrentAdapter(player);
    await adapter.open(stream, isCurrent: () => true);
    await waitFor(() => player.state.position.inSeconds >= 2);
    emit({
      'event': 'playback',
      'width': player.state.width,
      'position': player.state.position.inMilliseconds,
    });
    await dwell('stream_playing', 25);
    await adapter.seek(
      session,
      const Duration(seconds: 50),
      isCurrent: () => true,
    );
    await dwell('stream_seek', 15);
    final native = player.platform as NativePlayer;
    emit({
      'event': 'decoder',
      'hwdec': await native.getProperty('hwdec-current'),
      'drops': await native.getProperty('decoder-frame-drop-count'),
    });
    await player.stop();
    await session.close();
    await player.dispose();
    runApp(app(container));
    await dwell('post_close', 25);
    container.read(appDestinationProvider.notifier).go(AppDestination.home);
    await dwell('home_return', 15);
    ticking.value = false;
    await dwell('home_tickers_disabled', 20);
    runApp(const MaterialApp(home: SizedBox.shrink()));
    await dwell('blank_ui', 20);
    emit({'event': 'complete'});
  } catch (error, stack) {
    emit({
      'event': 'failure',
      'error': error.toString(),
      'stack': stack.toString(),
    });
    timer.cancel();
    await shutdown(runtime);
    exit(1);
  }
  timer.cancel();
  await shutdown(runtime);
  exit(0);
}
