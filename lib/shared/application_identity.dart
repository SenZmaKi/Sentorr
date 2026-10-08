/// Installation identity is independent of the formats shared with peers.
abstract final class ApplicationIdentity {
  static const channel = String.fromEnvironment(
    'UPDATE_CHANNEL',
    defaultValue: 'stable',
  );
  static const nightly = channel == 'nightly';
  static const name = nightly ? 'Sentorr Nightly' : 'Sentorr';
  static const dataDirectory = nightly ? 'SentorrNightlyData' : 'SentorrData';
  static const credentialsAccount = nightly
      ? 'com.sentorr.sentorr.nightly.credentials'
      : 'com.sentorr.sentorr.credentials';
  static const credentialPrefix = nightly ? 'nightly_' : '';
  static const driveBackupName = 'sentorr-backup.json';
  static const returnLink = nightly
      ? 'sentorr-nightly://return'
      : 'sentorr://return';
}
