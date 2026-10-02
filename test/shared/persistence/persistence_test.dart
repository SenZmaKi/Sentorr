import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/settings/repository.dart';
import 'package:sentorr/shared/persistence/app_paths.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';

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
