import 'manifest_repository.dart';
import 'models.dart';
import 'transfer.dart';
import 'update_repository.dart';

/// Recovery state cannot authorize an installation. Recover only a release
/// from an authenticated, unexpired manifest and verify its actual local file.
Future<({AppRelease release, UpdateArtifact artifact})?> restoreUpdate({
  required UpdateRepository repository,
  required UpdateManifestRepository manifests,
  required String currentVersion,
  required int currentBuild,
  required Set<String> channels,
}) async {
  try {
    final prepared = await repository.loadPrepared();
    if (prepared == null) return null;
    final manifest = await manifests.loadCached();
    final candidate = manifest?.latestCompatible(
      currentVersion: currentVersion,
      currentBuild: currentBuild,
      channels: channels,
    );
    if (candidate == null ||
        prepared.version != candidate.release.version.toString() ||
        prepared.build != candidate.release.build ||
        prepared.artifact.sha256 != candidate.artifact.sha256) {
      return null;
    }
    await verifyArtifact(
      repository.artifactFile(candidate.artifact),
      candidate.artifact,
    );
    return candidate;
  } catch (_) {
    return null;
  }
}
