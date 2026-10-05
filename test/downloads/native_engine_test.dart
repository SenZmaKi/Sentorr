import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/queue.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/downloads/torrents.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:test/test.dart';
import 'package:torrent_stream/torrent_stream.dart';

TorrentEngine loopbackEngine() => TorrentEngine(
  settings: const TorrentEngineSettings(
    transport: TorrentTransport.tcpOnly,
    enableDht: false,
    enableLsd: false,
    enableUpnp: false,
    enableNatPmp: false,
    listenInterfaces: '127.0.0.1:0',
  ),
);

Future<void> waitUntil(
  bool Function() ready, {
  Future<void> Function()? step,
}) async {
  final clock = Stopwatch()..start();
  while (!ready()) {
    if (clock.elapsed > const Duration(seconds: 25)) {
      throw TimeoutException('Native torrent timed out');
    }
    await step?.call();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory root;
  late Uint8List bytes, metadata;
  late Session seedSession;
  late TorrentPeer peer;
  late TorrentEngine engine;
  late DownloadQueue queue;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-native-download-');
    final sourceDir = await Directory('${root.path}/seed').create();
    bytes = Uint8List.fromList(
      List.generate(2 * 1024 * 1024 + 123, (i) => (i * 17 + 3) % 251),
    );
    final source = await File('${sourceDir.path}/fixture.bin')
        .writeAsBytes(bytes);
    metadata = createTorrentData(
      sourcePath: source.path,
      pieceSize: 128 * 1024,
    );
    seedSession = createSessionFromTags([
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
      savePath: sourceDir.path,
    );
    seed.unsetFlags(
      LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
    );
    await waitUntil(
      () => seed.getStatus().state == 5 && seedSession.listenPort != 0,
    );
    peer = TorrentPeer('127.0.0.1', seedSession.listenPort);
    engine = loopbackEngine();
    queue = DownloadQueue(
      EngineTorrents(engine),
      DownloadRepository(JsonFileStore(File('${root.path}/queue.json'))),
    );
    await queue.initialize(
      const DownloadSettings(seedingMode: SeedingMode.disabled),
    );
  });
  tearDown(() async {
    await queue.dispose();
    await engine.close();
    seedSession.close();
    await root.delete(recursive: true);
  });

  TorrentDownloadJob job({
    List<int> selection = const [0],
    Map<int, String> renames = const {0: 'Season 01/renamed.bin'},
  }) => TorrentDownloadJob(
    title: 'Fixture',
    torrentData: metadata,
    destinationDirectory: '${root.path}/download',
    selectedFileIndices: selection,
    renamedFiles: renames,
  );

  Future<DownloadItem> finish() async {
    await waitUntil(
      () => queue.items.single.status.isTerminal,
      step: queue.tick,
    );
    final item = queue.items.single;
    expect(item.status, DownloadStatus.completed, reason: item.error);
    return item;
  }

  test('a multi-file season pack finishes preparing every episode', () async {
    final pack = await Directory('${root.path}/pack').create();
    for (var n = 1; n <= 3; n++) {
      await File('${pack.path}/S01E0$n.bin')
          .writeAsBytes(bytes.sublist(0, 100003));
    }
    final data = createTorrentData(
      sourcePath: pack.path,
      pieceSize: 128 * 1024,
    );
    final hash = await engine.add(
      TorrentSource.metadata(data),
      owner: 'plan',
      directory: '${root.path}/pack-download',
      storage: TorrentStorage.kept,
    );
    final files = await engine.metadata(
      hash,
      timeout: const Duration(seconds: 3),
    );
    for (final file in files.where((f) => !f.isPadFile)) {
      await queue.enqueue(
        TorrentDownloadJob(
          title: file.path,
          torrentData: data,
          destinationDirectory: '${root.path}/pack-download',
          batchId: 'season',
          selectedFileIndices: [file.index],
          renamedFiles: {file.index: 'Season 01/${file.index}.bin'},
        ),
      );
    }
    await engine.release(hash, 'plan').timeout(const Duration(seconds: 3));
    await waitUntil(
      () => queue.items.every((i) => i.status != DownloadStatus.preparing),
    );
    expect(
      queue.items.where((i) => i.status == DownloadStatus.failed),
      isEmpty,
    );
  });

  test(
    'downloads exact bytes under the renamed path, then leaves the engine',
    () async {
      await queue.enqueue(job());
      await waitUntil(() => queue.items.single.infoHash != null);
      await engine.addPeers(queue.items.single.infoHash!, [peer]);
      final item = await finish();
      expect(item.downloadedBytes, bytes.length);
      expect(
        await File('${root.path}/download/Season 01/renamed.bin').readAsBytes(),
        bytes,
      );
      await waitUntil(() => engine.torrents.isEmpty);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'a stream of a downloading torrent shares it and the download completes',
    () async {
      final stream = TorrentStreamSession(
        engine: engine,
        config: TorrentStreamConfig(
          cacheDirectory: '${root.path}/cache',
          prepareContainer: false,
        ),
      );
      final files = await stream.open(
        TorrentSource.metadata(metadata),
        peers: [peer],
      );
      final endpoint = await stream.prepareFile(files.single.index);
      await queue.enqueue(job());
      final item = await finish();
      expect(item.infoHash, stream.infoHash);
      // The download moved the stream's files to the kept folder.
      expect(
        await File('${root.path}/download/Season 01/renamed.bin').readAsBytes(),
        bytes,
      );
      final client = HttpClient();
      final request = await client.getUrl(endpoint.uri);
      request.headers.set('Range', 'bytes=0-9');
      final response = await request.close();
      expect(
        await response.fold<List<int>>([], (a, b) => a..addAll(b)),
        bytes.sublist(0, 10),
      );
      client.close(force: true);
      await stream.close();
      await waitUntil(() => engine.torrents.isEmpty);
      expect(
        await File('${root.path}/download/Season 01/renamed.bin').readAsBytes(),
        bytes,
      );
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test('bad selections and escaping names fail without a hold', () async {
    for (final bad in [
      job(selection: [99]),
      job(renames: {0: '../escape.bin'}),
    ]) {
      await queue.enqueue(bad);
      await waitUntil(() => queue.items.last.status == DownloadStatus.failed);
    }
    await waitUntil(() => engine.torrents.isEmpty);
    expect(File('${root.path}/escape.bin').existsSync(), false);
  });
  test(
    'paused pack files stay unwanted while another owner downloads',
    () async {
      final folder = await Directory('${root.path}/pack-seed').create();
      for (final name in ['first.bin', 'second.bin']) {
        await File('${folder.path}/$name').writeAsBytes(Uint8List(1024 * 1024));
      }
      final data = createTorrentData(
        sourcePath: folder.path,
        pieceSize: 128 * 1024,
      );
      final seed = seedSession.addTorrentData(
        torrentData: data,
        savePath: root.path,
      );
      seed.unsetFlags(
        LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
      );
      await waitUntil(() => seed.getStatus().state == 5);
      final source = TorrentSource.metadata(data);
      final hash = await engine.add(
        source,
        owner: 'first',
        directory: '${root.path}/pack-download',
        storage: TorrentStorage.kept,
      );
      await engine.add(
        source,
        owner: 'second',
        directory: '${root.path}/pack-download',
        storage: TorrentStorage.kept,
      );
      final files = (await engine.metadata(hash))
          .where((f) => !f.isPadFile)
          .toList();
      expect(files, hasLength(2));
      await engine.want(hash, 'first', {files.first.index});
      await engine.want(hash, 'second', {files.last.index});
      await engine.setPaused(hash, 'second', true);
      await engine.addPeers(hash, [peer]);
      await waitUntil(
        () =>
            engine.torrent(hash)?.bytesOf(files.first.index) ==
            files.first.length,
      );
      var snapshot = engine.torrent(hash)!;
      expect(snapshot.wanted, {files.first.index});
      expect(snapshot.bytesOf(files.last.index), lessThan(files.last.length));
      expect(snapshot.paused, isFalse);
      await engine.setPaused(hash, 'second', false);
      await waitUntil(
        () =>
            engine.torrent(hash)?.bytesOf(files.last.index) ==
            files.last.length,
      );
      snapshot = engine.torrent(hash)!;
      expect(snapshot.wanted, {for (final f in files) f.index});
    },
  );
}
