# Android Google Drive OAuth clients

Project: `sentorr`. These public client identifiers are registered in Google Cloud;
Google Play services identifies the Android app by package name and signing certificate.
They are not replacements for the desktop OAuth client or its build-time credentials.

| Client | Package | Certificate SHA-1 | Client ID |
| --- | --- | --- | --- |
| stable-release | `com.sentorr.sentorr` | `AC:B6:15:94:32:49:3B:DF:22:CE:32:1D:12:BE:E6:BC:E2:A8:CE:80` | `1092185909599-h390vb8jtfe25tld0fup00le16u30qt9.apps.googleusercontent.com` |
| nightly-release | `com.sentorr.sentorr.nightly` | `AC:B6:15:94:32:49:3B:DF:22:CE:32:1D:12:BE:E6:BC:E2:A8:CE:80` | `1092185909599-4dg24mkqub8d81k4b6ffh672ap6kuc4o.apps.googleusercontent.com` |
| stable-debug | `com.sentorr.sentorr` | `85:49:03:D6:BB:75:09:E4:58:3A:83:4B:7D:4C:90:C9:AE:03:0A:42` | `1092185909599-ror06fdok3rlrofod3c66i7riqiqibng.apps.googleusercontent.com` |
| nightly-debug | `com.sentorr.sentorr.nightly` | `85:49:03:D6:BB:75:09:E4:58:3A:83:4B:7D:4C:90:C9:AE:03:0A:42` | `1092185909599-ug6n248uo25gnd30aaqd3lgdcneds4qj.apps.googleusercontent.com` |

Client labels were assigned in download creation order supplied by the maintainer.
The downloaded JSON files do not include package names or certificate fingerprints;
those registration values should be confirmed in Google Cloud if changed.

Original JSON files are backed up locally in the mounted Google Drive under
`My Drive/Sentorr/google-oauth/sentorr-android-<client>.json`.
Backup contents were read back and SHA-256 compared; remote upload is not independently verified.

Android uses Google Play services `AuthorizationClient` with only `drive.appdata`.
The SDK selects the registered OAuth client using the installed package name and
signing certificate; these Android client IDs are not passed as desktop defines.
No backend, client secret, browser redirect or localhost listener is used.

Only a connection preference is persisted by Sentorr. Google Play services keeps
and renews access; expired/rejected tokens are renewed without showing permission
UI during automatic sync. If permission is needed again, the viewer must reconnect.
Existing Android desktop-flow sign-ins need one explicit native reconnect.
Desktop keeps its original PKCE flow and build-time credentials.

Phone validation: restore normal background restrictions, connect, cancel/retry,
restart and sync, disconnect/reconnect, and check access to the existing desktop
backup. Local checks do not establish physical-device behavior.

Reference: https://developer.android.com/identity/authorization
