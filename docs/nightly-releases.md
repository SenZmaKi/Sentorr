# Nightly releases

The Release workflow builds the default branch daily at 00:00 UTC (03:00 in
Nairobi). **Run workflow** also builds a nightly from the selected branch.
Stable and other prerelease builds continue to start from version tags.

Nightlies reuse the existing platform matrix, native libraries, signing secrets,
checksums and quality checks. Each run publishes an immutable prerelease tagged
`v<base version>-nightly.<run number>.<attempt>` and is never GitHub's latest
stable release. The build number is the Unix timestamp at preparation time.

The CI checkout gets a crescent badge on launcher, splash, tray, Dock and window
icons in both themes. Launcher/display names read **Sentorr Nightly**. The
source artwork and stable builds keep their existing branding.

Nightlies use the `nightly` update channel and `appcast-nightly.xml`. Other
channels' appcasts survive release and configuration deployments. Non-macOS
nightly clients select only nightly entries in the signed update manifest.

Nightly and stable are separate applications. Android uses
`com.sentorr.sentorr.nightly` (the Kotlin namespace stays unchanged), macOS has a
separate bundle identifier and packaged `Sentorr Nightly.app`, Windows uses a
separate installer AppId and install directory, and Linux uses a separate GTK
application/desktop identifier. The CI identity script runs before building;
`UPDATE_CHANNEL=nightly` also selects independent data/download folders,
credential keys. Both channels share the same validated Drive backup. Existing stable identifiers remain
unchanged. There is no automatic copy of stable data or pairing credentials.

Both channels remain discoverable through `_sentorr._tcp`. Nightly device names
are labelled, and each installation gets its own pairing identity. Explicitly
paired installations can sync, copy and stream when their formats match.
See [sync compatibility](sync/ARCHITECTURE.md#compatibility-before-exchange).
Drive snapshots use `sentorr-backup.json` across both channels. Previously
separate `sentorr-nightly-backup.json` snapshots are validated, merged and
consolidated into the shared name. Compatibility follows declared data formats,
not the app version or channel. Unsupported snapshots block synchronization
without overwriting them. Each installation signs in independently.
Windows/macOS retain the existing unsigned/ad-hoc signing behavior.

The download page has in-page Stable/Nightly tabs. The selected tab is kept in
`?channel=stable` or `?channel=nightly` without reloading; a bare `/download`
(or an unknown channel) is rewritten to `?channel=stable`. Both tabs query
GitHub for published release assets, preserving processor selection when
switching channels. Failed lookups leave downloads disabled and direct visitors
to the release list. Without JavaScript, stable links and a nightly-release link
remain available.

Local validation: `npm run check` and `npm run build` in `website/`,
`flutter test test/updates`, and Python with Pillow:
`python -m unittest discover -s tool/release/tests`.

Download asset/channel regressions: `node --experimental-strip-types --test
website/test/release-channel.test.mjs`.
