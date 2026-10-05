/// The Google Cloud "Desktop app" OAuth client Sentorr signs in with.
/// Pass both at build time (`--dart-define=GOOGLE_DRIVE_CLIENT_ID=...`);
/// without them the Drive option is hidden. A desktop client's secret is
/// not confidential, since Google expects it inside the shipped app.
const driveClientId = String.fromEnvironment('GOOGLE_DRIVE_CLIENT_ID');
const driveClientSecret = String.fromEnvironment('GOOGLE_DRIVE_CLIENT_SECRET');

bool get driveConfigured => driveClientId.isNotEmpty;

/// Reaches only Sentorr's own hidden folder, never the viewer's files.
const driveScope = 'https://www.googleapis.com/auth/drive.appdata';
