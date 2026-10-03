import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:sentorr/shared/persistence/app_paths.dart';
import 'package:sentorr/updates/manifest_repository.dart';
import 'package:sentorr/updates/models.dart';
import 'package:sentorr/updates/restore.dart';
import 'package:sentorr/updates/update_repository.dart';
import 'package:test/test.dart';

class _Manifests extends UpdateManifestRepository {
  _Manifests(AppPaths paths, this.manifest) : super(paths: paths, dio: Dio());
  final UpdateManifest manifest;
  @override
  Future<UpdateManifest?> loadCached() async => manifest;
}

void main() {
  test('recovery verifies the owned artifact and never trusts a saved external path', () async {
    final root = await Directory.systemTemp.createTemp('sentorr-restore-');
    addTearDown(() => root.delete(recursive: true));
    final paths = await AppPaths.initialize(rootDirectory: root);
    final repo = UpdateRepository(paths: paths);
    final bytes = [1, 2, 3, 4];
    final artifact = UpdateArtifact(
      platform: UpdateTarget.current.platform,
      architecture: 'any',
      url: Uri.parse(
        'https://github.com/SenZmaKi/Sentorr/releases/download/v1.0.0/update.zip',
      ),
      fileName: 'update.zip',
      sizeBytes: 4,
      sha256: sha256.convert(bytes).toString(),
    );
    final release = AppRelease(
      version: Version.parse('1.0.0'),
      build: 2,
      channel: 'stable',
      mandatory: false,
      notes: '',
      artifacts: [artifact],
    );
    final manifests = _Manifests(
      paths,
      UpdateManifest(
        schemaVersion: 1,
        generatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        releases: [release],
      ),
    );
    addTearDown(() => manifests.dio.close());
    final external = File('${root.path}/external.zip');
    await external.writeAsBytes(bytes);
    await repo.savePrepared(
      PreparedUpdate(
        version: '1.0.0',
        build: 2,
        artifact: artifact,
        filePath: external.path,
        platformPrepared: false,
      ),
    );
    Future<Object?> restore() => restoreUpdate(
      repository: repo,
      manifests: manifests,
      currentVersion: '0.1.0',
      currentBuild: 1,
      channels: {'stable'},
    );
    expect(await restore(), isNull);
    await repo.artifactFile(artifact).writeAsBytes(bytes);
    expect(await restore(), isNotNull);
    await repo.artifactFile(artifact).writeAsBytes([1, 2, 3, 5]);
    expect(await restore(), isNull);
  });
}
