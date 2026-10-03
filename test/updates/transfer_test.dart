import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sentorr/updates/models.dart';
import 'package:sentorr/updates/transfer.dart';
import 'package:test/test.dart';

void main() {
  test('artifact verification rejects wrong size and altered bytes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sentorr-update-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/update.apk');
    final bytes = [1, 2, 3, 4];
    await file.writeAsBytes(bytes);
    final artifact = UpdateArtifact(
      platform: 'android',
      architecture: 'arm64',
      url: Uri.parse(
        'https://github.com/SenZmaKi/Sentorr/releases/download/v1.0.0/update.apk',
      ),
      fileName: 'update.apk',
      sizeBytes: 4,
      sha256: sha256.convert(bytes).toString(),
    );
    await verifyArtifact(file, artifact);
    await file.writeAsBytes([1, 2, 3]);
    await expectLater(verifyArtifact(file, artifact), throwsFormatException);
    await file.writeAsBytes([1, 2, 3, 5]);
    await expectLater(verifyArtifact(file, artifact), throwsFormatException);
  });
  test('signed artifact metadata cannot escape its download directory', () {
    for (final name in ['../app.apk', r'..\app.apk']) {
      expect(
        () => UpdateArtifact.fromJson({
          'platform': 'android',
          'architecture': 'arm64',
          'url': 'https://github.com/file.apk',
          'fileName': name,
          'sizeBytes': 1,
          'sha256': 'a' * 64,
        }),
        throwsFormatException,
      );
    }
  });
}
