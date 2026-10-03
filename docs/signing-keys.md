# Sentorr signing keys

Sentorr follows Senpwai's independent signing authorities. Private keys never
belong in the repository, logs, or packaged application.

| Authority | Actions secret | Keychain service (account `Sentorr`) | App trust root |
| --- | --- | --- | --- |
| Source endpoints | `SOURCE_DIRECTORY_PRIVATE_KEY` | `com.senzmaki.sentorr.signing.source-directory` | `lib/shared/signed_envelope.dart` |
| Android/Windows/Linux releases | `UPDATE_MANIFEST_PRIVATE_KEY` | `com.senzmaki.sentorr.signing.update-manifest` | `lib/shared/signed_envelope.dart` |
| macOS Sparkle archives | `SPARKLE_PRIVATE_KEY` | `com.senzmaki.sentorr.signing.sparkle` | `macos/Runner/Info.plist` |

Ed25519 values are base64-encoded 32-byte seeds. The public halves are committed;
the three private seeds are stored in GitHub Actions secrets and macOS Keychain.
The maintainer's locally synced Google Drive holds
`My Drive/Sentorr/signing-keys/sentorr-ed25519-signing.env` (mode 600).
Local backup readback is verified; remote Drive synchronization is managed by
Google Drive and was not independently confirmed.

Android uses a new independent RSA release certificate, package
`com.sentorr.sentorr`, and alias `sentorr`. The keystore and recovery environment
file are in `My Drive/Sentorr/android-keychain/`, mode 600. Actions secrets are
`SENTORR_ANDROID_KEYSTORE_BASE64`, `SENTORR_ANDROID_KEYSTORE_PASSWORD`,
`SENTORR_ANDROID_KEY_PASSWORD`, and `SENTORR_ANDROID_KEY_ALIAS`. Each has a
Keychain recovery entry named `com.senzmaki.sentorr.signing.` followed by the
lowercase secret name. All copies were read back and compared during setup.
Keep the certificate stable and increase the pubspec build number for upgrades.
Debug-signed installations need to be removed before installing this release
identity; their certificate cannot be replaced by an in-place Android upgrade.

Check existence without printing secrets:

```sh
security find-generic-password -a Sentorr -s com.senzmaki.sentorr.signing.source-directory
gh secret list --repo SenZmaKi/Sentorr
```

Recovery values should be piped directly into `gh secret set`; do not print
Keychain passwords in a terminal or paste them into chat. Do not rerun key
creation to repair missing workflow secrets. Recover the existing identity.

After shipping, rotate through an application signed by the old authority that
trusts the new public key first. Existing clients cannot accept a feed signed
only by a newly generated key. Sparkle authenticates updates; it does not replace
Apple Developer ID signing or notarization. macOS packaging remains ad-hoc signed.
