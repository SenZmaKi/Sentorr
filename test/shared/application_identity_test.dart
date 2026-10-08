import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sentorr/shared/persistence/credential_store.dart';
import 'package:sentorr/backup/drive/drive_client.dart';
import 'package:sentorr/backup/drive/sign_in_page.dart';
import 'package:sentorr/shared/application_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'credential reads, writes and disconnect only touch this channel',
    () async {
      const nightly = bool.fromEnvironment('EXPECT_NIGHTLY');
      FlutterSecureStorage.setMockInitialValues({
        'google_drive_refresh_token': 'stable-token',
        'nightly_google_drive_refresh_token': 'nightly-token',
      });
      final store = CredentialStore();
      expect(
        await store.readDriveToken(),
        nightly ? 'nightly-token' : 'stable-token',
      );
      await store.writeDriveToken('new-token');
      await store.deleteDriveToken();
      final other = await const FlutterSecureStorage().read(
        key: nightly
            ? 'google_drive_refresh_token'
            : 'nightly_google_drive_refresh_token',
      );
      expect(other, nightly ? 'stable-token' : 'nightly-token');
    },
  );

  test(
    'stable identifiers stay unchanged and nightly uses separate storage',
    () {
      const expectedNightly = bool.fromEnvironment('EXPECT_NIGHTLY');
      expect(ApplicationIdentity.nightly, expectedNightly);
      expect(
        ApplicationIdentity.dataDirectory,
        expectedNightly ? 'SentorrNightlyData' : 'SentorrData',
      );
      expect(
        ApplicationIdentity.credentialsAccount,
        expectedNightly
            ? 'com.sentorr.sentorr.nightly.credentials'
            : 'com.sentorr.sentorr.credentials',
      );
      expect(
        ApplicationIdentity.credentialPrefix,
        expectedNightly ? 'nightly_' : '',
      );
      expect(DriveBackupClient.fileName, 'sentorr-backup.json');
      expect(
        androidReturnLink,
        expectedNightly ? 'sentorr-nightly://return' : 'sentorr://return',
      );
    },
  );
}
