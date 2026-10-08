# Releases and updates

The workflows adapt Senpwai's architecture:

- `ci.yml`: check formatting, lint, Flutter tests, serial torrent-engine tests and
  signer analysis on pushes, pull requests, manual runs and the daily schedule.
- `deploy-source-directory.yml`: sign endpoint configuration and preserve
  existing update manifests and both Sparkle channels while deploying Pages.
- `release.yml`: validate a `v<pubspec version>` tag and positive build number,
  reuse the quality gate, build Android ABI APKs, Linux x64/arm64 AppImages,
  Windows x64 Inno installers and a universal macOS ZIP/DMG; stage a draft,
  deploy signed feeds, then publish the complete release. Published tags cannot
  be overwritten. Stable and prerelease channels follow Senpwai's feed layout.

The app uses signed manifests for Android/Windows/Linux and Sparkle for macOS.
Both manifests and source configuration have separate Ed25519 authorities.
Artifacts must pass signed byte-length and SHA-256 checks before install.
Verified downloads persist across restarts; recovery verifies an unexpired signed
manifest (including the local signed cache) before using an existing file. Linux replacement occurs only when
Install and restart is selected. Android opens the system installer and may
first require the user to allow installation from Sentorr. Windows uses the
Inno silent installer. macOS installation/relaunch is managed by Sparkle.

Settings → Updates controls automatic download, check, cancel, retry, install
and source refresh. HTTP transfers run while the Sentorr process is alive;
Android does not yet have Senpwai's foreground-service HTTP download runtime.
A terminated transfer restarts on the next run; completed verified artifacts
are reused. Torrent downloads retain their own existing queue and engine.

The native streaming bridge uses `libtorrent_dart`'s published release
binaries, which its build hook downloads for each target architecture (macOS
universal builds fetch both slices). The app bundle is sealed after final
framework embedding and its nested signatures are verified. Use
`libtorrent_dart` 1.1.2 or newer: earlier published binaries lack the streaming
symbols. AppImages need system GTK and the normal desktop environment.

Pages is configured for Actions at `https://senzmaki.github.io/Sentorr/`.
Its deployment environment permits `master` branches and `v*.*.*` release tags.
The initial empty manifest is used only if the remote feed returns HTTP 404;
subsequent feeds must verify with the existing release key. Network/server
errors fail deployment rather than replacing the existing feed with empty data.
`UPDATE_MANIFEST_URL` and `UPDATE_CHANNEL` are build-time overrides.

See [signing and recovery](../docs/signing-keys.md). Workflow definitions remain
local until committed/pushed. No release tag or production update was published
while implementing this change.

Local validation on 3 October 2026: 429 Flutter tests passed, analysis and
formatting were clean, signer analysis passed, and actionlint accepted all three
workflows. Bootstrap source/update feeds and the Sparkle appcast signature were
signed and verified using Sentorr's separate trust roots. The rebuilt macOS
Debug app passed strict nested signature verification after the final bundle
seal. Windows, Linux and Android release packaging, remote Actions execution,
actual update installation and remote Drive synchronization remain unverified.
