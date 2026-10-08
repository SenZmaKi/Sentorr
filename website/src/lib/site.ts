import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const base = import.meta.env.BASE_URL.endsWith('/')
  ? import.meta.env.BASE_URL
  : `${import.meta.env.BASE_URL}/`;

/** Resolves an internal path against the site's base, e.g. `url('download')`. */
export const url = (path = '') => `${base}${path.replace(/^\//, '')}`;

import { repo } from './release-channel';
export { repo } from './release-channel';
export const releases = `${repo}/releases`;
export const latestRelease = `${releases}/latest`;
export const issues = `${repo}/issues`;

// The release workflow tags `v<pubspec version>` and builds this site with it,
// so download links point at the files of the version being released.
export const version = readFileSync(resolve(process.cwd(), '../pubspec.yaml'), 'utf8')
  .match(/^version:\s*([^+\s]+)/m)![1];
export const releaseDownloads = `${releases}/download/v${version}`;

export interface Architecture {
  value: string;
  label: string;
  /** Release asset name, e.g. `Sentorr-windows-x64-setup.exe`. */
  file: string;
}

export type PlatformId = 'windows' | 'macos' | 'linux' | 'android';

export interface Platform {
  id: PlatformId;
  name: string;
  requirement: string;
  format: string;
  /** The first entry is the default until the visitor's processor is detected. */
  architectures: Architecture[];
  note: string;
}

// Asset names follow .github/workflows/release.yml.
export const platforms: Platform[] = [
  {
    id: 'windows',
    name: 'Windows',
    requirement: 'Windows 10 or 11',
    format: 'Installer',
    architectures: [
      { value: 'x64', label: 'x64', file: 'Sentorr-windows-x64-setup.exe' },
    ],
    note: 'Unsigned for now: choose More info → Run anyway if SmartScreen asks. ARM PCs run it through Windows emulation.',
  },
  {
    id: 'macos',
    name: 'macOS',
    requirement: 'Apple silicon and Intel',
    format: '.dmg',
    architectures: [{ value: 'universal', label: 'Universal', file: 'Sentorr-macos-universal.dmg' }],
    note: 'Ad-hoc signed: right-click the app and choose Open the first time.',
  },
  {
    id: 'linux',
    name: 'Linux',
    requirement: 'Any recent distribution',
    format: 'AppImage',
    architectures: [
      { value: 'x64', label: 'x86_64', file: `Sentorr-${version}-x86_64.AppImage` },
      { value: 'arm64', label: 'aarch64 (ARM64)', file: `Sentorr-${version}-aarch64.AppImage` },
    ],
    note: 'Make it executable, then run it. No install needed.',
  },
  {
    id: 'android',
    name: 'Android',
    requirement: 'Phones and tablets',
    format: 'APK',
    architectures: [
      { value: 'arm64', label: 'ARM64 (most phones)', file: `Sentorr-${version}-arm64.apk` },
      { value: 'arm', label: 'ARMv7 (older phones)', file: `Sentorr-${version}-arm.apk` },
      { value: 'x64', label: 'x86_64 (emulators)', file: `Sentorr-${version}-x64.apk` },
    ],
    note: 'Allow installs from your browser when Android asks.',
  },
];

export type Destination = 'home' | 'features' | 'download' | 'source';

/** The site's destinations, drawn like the app's rail and bottom navigation. */
export const destinations: { id: Destination; label: string; icon: string; href: string; external?: boolean }[] = [
  { id: 'home', label: 'Home', icon: 'home', href: url() },
  { id: 'features', label: 'Features', icon: 'widgets', href: url('#features') },
  { id: 'download', label: 'Download', icon: 'download', href: url('download') },
  { id: 'source', label: 'Source', icon: 'code', href: repo, external: true },
];
