# Signed source directory

Edit `source_directory.payload.json`, increase `version`, and renew `expiresAt`.
The Pages workflow signs the exact JSON bytes with the source-directory key.
The app verifies signatures, expiration, endpoint HTTPS/host constraints and
rollback before accepting changes. It caches the signed envelope and ETag;
invalid caches use bundled defaults and failed refreshes retain valid endpoints.

Bootstrap loads the cache, then refreshes without blocking the UI. Searches wait
for launch refresh and resolve the current endpoint after that wait. All three
adapters (Pirate Bay, YTS, Bitsearch) consume the directory. Settings → Updates
also offers manual refresh. Remote configuration changes endpoints only;
provider parser changes require an app release.

`SOURCE_DIRECTORY_URL` can override the feed at build time. The default is
`https://senzmaki.github.io/Sentorr/source-directory.json`.

See [key recovery](../docs/signing-keys.md) and
[release workflow](../update-manifest/README.md).
