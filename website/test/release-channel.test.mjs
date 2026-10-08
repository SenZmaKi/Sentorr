import assert from 'node:assert/strict';
import { test } from 'node:test';
import { assetFor, loadChannel } from '../src/lib/release-channel.ts';

test('resolves every platform asset from the actual nightly version', () => {
  const names = ['Sentorr-3.0.0-nightly.12.1-arm64.apk',
    'Sentorr-3.0.0-nightly.12.1-x86_64.AppImage',
    'Sentorr-3.0.0-nightly.12.1-aarch64.AppImage',
    'Sentorr-windows-x64-setup.exe', 'Sentorr-macos-universal.dmg'];
  const assets = names.map(name => ({ name, browser_download_url: `https://example.com/${name}` }));
  for (const [platform, architecture, index] of [['android', 'arm64', 0], ['linux', 'x64', 1],
    ['linux', 'arm64', 2], ['windows', 'x64', 3], ['macos', 'universal', 4]]) {
    assert.equal(assetFor(assets, platform, architecture)?.name, names[index]);
  }
  assert.equal(assetFor(assets, 'android', 'arm'), undefined);
});

test('nightly lookup skips drafts, stable and other prereleases', async () => {
  const original = globalThis.fetch;
  try {
    globalThis.fetch = async () => ({ ok: true, json: async () => [
      { tag_name: 'v3.0.0-nightly.15.1', draft: true },
      { tag_name: 'v3.1.0-beta.1', draft: false },
      { tag_name: 'v3.0.0', draft: false },
      { tag_name: 'v3.0.0-nightly.14.1', draft: false },
    ] });
    assert.equal((await loadChannel('nightly')).tag_name, 'v3.0.0-nightly.14.1');
    globalThis.fetch = async () => ({ ok: true, json: async () => [] });
    await assert.rejects(loadChannel('nightly'), /No published release/);
    globalThis.fetch = async () => ({ ok: false, status: 403 });
    await assert.rejects(loadChannel('stable'), /403/);
  } finally {
    globalThis.fetch = original;
  }
});
