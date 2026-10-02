import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:path/path.dart' as p;
import 'package:sentorr/app/services.dart';
import 'package:sentorr/downloads/manager.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/imdb/models.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/notifier.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/library/playback.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/stream/offline_source.dart';
import 'package:sentorr/player/torrent_search.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/persistence/app_paths.dart';
import 'package:sentorr/torrents/engine.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:test/test.dart';
import 'package:torrent_stream/torrent_stream.dart';

import '../support/fake_library.dart';

Future<void> waitUntil(bool Function() ready) async {
  final clock = Stopwatch()..start();
  while (!ready()) {
    if (clock.elapsed > const Duration(seconds: 25)) {
      throw TimeoutException('Timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  test(
    'an episode downloads into the library layout and plays from disk',
    () async {
      final root = await Directory.systemTemp.createTemp('sentorr-planner-');
      final seedDir = await Directory('${root.path}/seed').create();
      final bytes = Uint8List.fromList(
        List.generate(1024 * 1024 + 9, (i) => (i * 13 + 5) % 251),
      );
      final source = await File('${seedDir.path}/Show.S01E03.1080p.mkv')
          .writeAsBytes(bytes);
      final metadata = createTorrentData(
        sourcePath: source.path,
        pieceSize: 64 * 1024,
      );
      final seedSession = createSessionFromTags([
        LibtorrentTagItem.settingsString(
          LibtorrentSettingsTag.listenInterfaces,
          '127.0.0.1:0',
        ),
        for (final tag in [
          LibtorrentSettingsTag.enableDht,
          LibtorrentSettingsTag.enableLsd,
          LibtorrentSettingsTag.enableUpnp,
          LibtorrentSettingsTag.enableNatpmp,
          LibtorrentSettingsTag.enableOutgoingUtp,
          LibtorrentSettingsTag.enableIncomingUtp,
        ])
          LibtorrentTagItem.settingsBool(tag, false),
      ]);
      final seed = seedSession.addTorrentData(
        torrentData: metadata,
        savePath: seedDir.path,
      );
      seed.unsetFlags(
        LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
      );
      await waitUntil(
        () => seed.getStatus().state == 5 && seedSession.listenPort != 0,
      );
      final magnet = Uri.parse(
        '${seed.makeMagnetUri()}&x.pe=127.0.0.1:${seedSession.listenPort}',
      );
      final release = TorrentRelease(
        source: TorrentSourceId.pirateBay,
        name: 'Show S01E03 1080p',
        infoHash: parseMagnetUri(magnet.toString()).infohashHex,
        magnet: magnet,
        seeders: 1,
        sizeBytes: bytes.length,
        resolution: 1080,
      );
      final engine = TorrentEngine(
        settings: const TorrentEngineSettings(
          transport: TorrentTransport.tcpOnly,
          enableDht: false,
          enableLsd: false,
          enableUpnp: false,
          enableNatPmp: false,
          listenInterfaces: '127.0.0.1:0',
        ),
      );
      final library = MemoryLibrary();
      final container = ProviderContainer(
        overrides: [
          appPathsProvider.overrideWithValue(
            await AppPaths.initialize(rootDirectory: root),
          ),
          initialSettingsProvider.overrideWithValue(const AppSettings()),
          torrentEngineProvider.overrideWithValue(engine),
          torrentSearchProvider.overrideWithValue(
            (item, {title, cancel}) async => TorrentResolution(
              query: TorrentQuery(title: 'Show'),
              candidates: [
                TorrentCandidate(
                  release: release,
                  score: 1,
                  qualityScore: 1,
                  availabilityScore: 1,
                  sizeScore: 1,
                  requiresFileSelection: false,
                ),
              ],
              failures: const [],
            ),
          ),
          ...libraryOverrides(const [], library),
        ],
      );
      final item = PlaybackItem(
        title: ImdbTitle(id: 'tt90', title: 'The Pilot'),
        series: ImdbTitle(id: 'tt9', title: 'Show', releaseYear: 2019),
        season: 1,
        episode: 3,
      );
      final offline = Provider((ref) => offlineSourceFor(ref, item));
      final expected = p.join(
        root.path,
        'downloads',
        'Show (2019)',
        'Season 01',
        'Show S01E03.mkv',
      );
      try {
        await container
            .read(downloadQueueProvider)
            .initialize(const DownloadSettings());
        container.listen(downloadsProvider, (_, _) {});
        await container.read(downloadPlannerProvider).download(item);
        final entry = container.read(libraryProvider).single;
        expect(entry.path, expected);
        expect(library.saved.single.id, 'tt90');
        await waitUntil(
          () => container.read(offlineStateProvider('tt90')) is Downloaded,
        );
        expect(await File(expected).readAsBytes(), bytes);
        expect(container.read(offline), isA<LocalFile>());
        // The planner's hold is gone; the finished download let go too.
        await waitUntil(() => engine.torrents.isEmpty);

        await container.read(libraryProvider.notifier).remove('tt90');
        expect(File(expected).existsSync(), false);
        expect(Directory(p.dirname(p.dirname(expected))).existsSync(), false);
        expect(
          container.read(offlineStateProvider('tt90')),
          isA<NotDownloaded>(),
        );
      } finally {
        container.dispose();
        await engine.close();
        seedSession.close();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
