import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'models.dart';
import 'update_repository.dart';

/// Sentorr's queue owns torrent pieces; HTTP update artifacts use its network
/// owner instead. A verified artifact survives restarts without redownloading.
class UpdateTransfer {
  const UpdateTransfer(this.dio, this.repository);
  final Dio dio;
  final UpdateRepository repository;

  Future<File> download(
    AppRelease release,
    UpdateArtifact artifact, {
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    final file = repository.artifactFile(artifact);
    if (await file.exists()) {
      try {
        await verifyArtifact(file, artifact);
        return file;
      } catch (_) {
        await file.delete();
      }
    }
    final part = repository.partialArtifactFile(artifact);
    await file.parent.create(recursive: true);
    await dio.download(
      artifact.url.toString(),
      part.path,
      cancelToken: cancelToken,
      options: Options(headers: {'Cache-Control': 'no-cache'}),
      onReceiveProgress: (received, total) {
        if (received > artifact.sizeBytes) {
          cancelToken.cancel('Update exceeds signed size');
        }
        onProgress(received, artifact.sizeBytes);
      },
    );
    await verifyArtifact(part, artifact);
    return part.rename(file.path);
  }
}

Future<void> verifyArtifact(File file, UpdateArtifact artifact) async {
  if (await file.length() != artifact.sizeBytes ||
      (await sha256.bind(file.openRead()).first).toString() !=
          artifact.sha256) {
    throw const FormatException('Update integrity verification failed');
  }
}
