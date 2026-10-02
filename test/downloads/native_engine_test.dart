import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:sentorr/downloads/backend.dart';
import 'package:sentorr/downloads/engine.dart';
import 'package:sentorr/downloads/isolate_runtime.dart';
import 'package:sentorr/downloads/models.dart';
import 'package:sentorr/downloads/repository.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:test/test.dart';

const localSettings = DownloadSettings(
  enableDht: false,
  enableLsd: false,
  enableUpnp: false,
  enableNatPmp: false,
);

Future<void> waitUntil(bool Function() ready) async {
  final clock = Stopwatch()..start();
  while (!ready()) {
    if (clock.elapsed > const Duration(seconds: 25)) {
      throw TimeoutException('Native torrent timed out');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  test(
    'native queue downloads exact bytes from a local libtorrent peer',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'sentorr-native-download-',
      );
      final sourceDir = await Directory('${root.path}/seed').create();
      final bytes = Uint8List.fromList(
        List.generate(2 * 1024 * 1024 + 123, (i) => (i * 17 + 3) % 251),
      );
      final source = await File('${sourceDir.path}/fixture.bin')
          .writeAsBytes(bytes);
      final metadata = createTorrentData(
        sourcePath: source.path,
        pieceSize: 128 * 1024,
      );
      final seedSession = createSessionFromTags([
        LibtorrentTagItem.settingsString(
          LibtorrentSettingsTag.listenInterfaces,
          '127.0.0.1:0',
        ),
        LibtorrentTagItem.settingsBool(LibtorrentSettingsTag.enableDht, false),
        LibtorrentTagItem.settingsBool(LibtorrentSettingsTag.enableLsd, false),
        LibtorrentTagItem.settingsBool(LibtorrentSettingsTag.enableUpnp, false),
        LibtorrentTagItem.settingsBool(
          LibtorrentSettingsTag.enableNatpmp,
          false,
        ),
      ]);
      final backend = LibtorrentDownloadBackend();
      final engine = DownloadEngine(
        backend,
        DownloadRepository(JsonFileStore(File('${root.path}/queue.json'))),
      );
      try {
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
        await engine.initialize(localSettings);
        await engine.enqueue(
          TorrentDownloadJob(
            title: 'Fixture',
            torrentData: metadata,
            destinationDirectory: '${root.path}/download',
            selectedFileIndices: [0],
            renamedFiles: {0: 'renamed.bin'},
          ),
        );
        final target = backend.session.getTorrents().single;
        target.connectPeer(address: '127.0.0.1', port: seedSession.listenPort);
        final clock = Stopwatch()..start();
        while (engine.items.single.status != DownloadStatus.completed) {
          await engine.tick();
          expect(
            engine.items.single.status,
            isNot(DownloadStatus.failed),
            reason: engine.items.single.error,
          );
          if (clock.elapsed > const Duration(seconds: 25)) {
            throw TimeoutException('Download timed out');
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(engine.items.single.downloadedBytes, bytes.length);
        expect(
          await File('${root.path}/download/renamed.bin').readAsBytes(),
          bytes,
        );
        expect(backend.session.getTorrents(), isEmpty);
      } finally {
        await engine.dispose();
        seedSession.close();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test(
    'native boundary rejects bad selections, metadata and escaping paths',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'sentorr-native-validation-',
      );
      final source = await File('${root.path}/fixture.bin')
          .writeAsBytes([1, 2, 3]);
      final metadata = createTorrentData(sourcePath: source.path);
      final backend = LibtorrentDownloadBackend()..configure(localSettings);
      TorrentDownloadJob job({
        List<int> selection = const [],
        Map<int, String> renames = const {},
      }) => TorrentDownloadJob(
        title: 'Test',
        torrentData: metadata,
        destinationDirectory: '${root.path}/download',
        selectedFileIndices: selection,
        renamedFiles: renames,
      );
      try {
        expect(() => backend.add(job(selection: [99])), throwsArgumentError);
        expect(backend.session.getTorrents(), isEmpty);
        expect(
          () => backend.add(job(renames: {0: '../escape.bin'})),
          throwsArgumentError,
        );
        expect(
          () => backend.add(
            TorrentDownloadJob(
              title: 'Bad',
              torrentData: Uint8List(0),
              destinationDirectory: root.path,
            ),
          ),
          throwsArgumentError,
        );
      } finally {
        backend.close();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'background isolate handles commands, restoration and awaited shutdown',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'sentorr-download-isolate-',
      );
      final source = await File('${root.path}/fixture.bin')
          .writeAsBytes([1, 2, 3, 4]);
      final metadata = createTorrentData(sourcePath: source.path);
      final state = '${root.path}/queue.json';
      final runtime = DownloadIsolateRuntime(
        stateFile: state,
        initialSettings: localSettings,
      );
      final errors = <Object>[];
      final subscription = runtime.stateStream.listen(
        (_) {},
        onError: errors.add,
      );
      try {
        // Enqueue before readiness: initialization is gated, as in Senpwai.
        final id = await runtime.enqueue(
          TorrentDownloadJob(
            title: 'Fixture',
            torrentData: metadata,
            destinationDirectory: root.path,
          ),
        );
        await runtime.pause(id);
        expect(runtime.currentState.single.status, DownloadStatus.paused);
        await runtime.dispose();
        final restored = DownloadIsolateRuntime(
          stateFile: state,
          initialSettings: localSettings,
        );
        try {
          await restored.initialize();
          expect(restored.currentState.single.status, DownloadStatus.paused);
          await restored.resume(id);
          await waitUntil(
            () =>
                restored.currentState.single.status == DownloadStatus.completed,
          );
          expect(restored.currentState.single.progress, 1);
          await restored.clearHistory();
          expect(restored.currentState, isEmpty);
        } finally {
          await restored.dispose();
        }
        expect(errors, isEmpty);
        await expectLater(runtime.pause(id), throwsStateError);
      } finally {
        await runtime.dispose();
        await subscription.cancel();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );
}
