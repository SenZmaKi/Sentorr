import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/settings/repository.dart';
import 'package:sentorr/shared/persistence/app_paths.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';

class _CountingStore extends JsonFileStore {
  _CountingStore(super.file);
  int writes = 0;
  Completer<void>? gate;
  @override
  Future<void> replace(String contents) async {
    writes++;
    await gate?.future;
    await super.replace(contents);
  }
}

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sentorr-persistence-');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('queued replacements finish with the latest settings and no temporary files', () async {
    final paths = await AppPaths.initialize(rootDirectory: root);
    final store = JsonFileStore(paths.settingsFile);
    final repository = SettingsRepository(store);
    await repository.load();
    await Future.wait(
      List.generate(
        20,
        (i) => repository.save(AppSettings(imageCacheMaxBytes: (i + 1) * 1024)),
      ),
    );
    expect((await repository.load()).imageCacheMaxBytes, 20 * 1024);
    expect(
      await paths.settingsFile.parent
          .list()
          .where((file) => file.path.endsWith('.tmp'))
          .length,
      0,
    );
  });

  test(
    'malformed settings are preserved before defaults replace them',
    () async {
      final paths = await AppPaths.initialize(rootDirectory: root);
      await paths.settingsFile.writeAsString('{broken');
      final repository = SettingsRepository(JsonFileStore(paths.settingsFile));
      expect(
        (await repository.load()).imageCacheMaxBytes,
        const AppSettings().imageCacheMaxBytes,
      );
      final preserved = await paths.settingsFile.parent
          .list()
          .where((file) => file.path.endsWith('.corrupt'))
          .toList();
      expect(preserved, hasLength(1));
      expect(await File(preserved.single.path).readAsString(), '{broken');
    },
  );

  test('a burst shares one durable replacement', () async {
    final store = _CountingStore(File('${root.path}/state.json'));
    final saves = List.generate(20, (i) => store.write({'value': i}));
    await Future.wait(saves);
    expect(store.writes, 1);
    expect(await store.read(), {'value': 19});
  });

  test(
    'writes arriving during IO coalesce and flushed waits for them',
    () async {
      final store = _CountingStore(File('${root.path}/state.json'));
      final gate = store.gate = Completer<void>();
      final first = store.write({'value': 0});
      await Future<void>.delayed(Duration.zero);
      final saves = List.generate(20, (i) => store.write({'value': i + 1}));
      var flushed = false;
      final flush = store.flushed.then((_) => flushed = true);
      await Future<void>.delayed(Duration.zero);
      expect(flushed, false);
      gate.complete();
      await Future.wait([first, ...saves, flush]);
      expect(store.writes, 2);
      expect(await store.read(), {'value': 20});
    },
  );

  test('a failed write does not prevent a later save', () async {
    final obstacle = File('${root.path}/blocked');
    await obstacle.writeAsString('blocking parent directory');
    final store = JsonFileStore(File('${obstacle.path}/state.json'));
    await expectLater(
      store.write({'value': 1}),
      throwsA(isA<FileSystemException>()),
    );
    await obstacle.delete();
    await store.write({'value': 2});
    expect(await store.read(), {'value': 2});
  });
}
