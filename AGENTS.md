# Sentorr

Sentorr streams movies and TV series from torrents. We are migrating the existing Svelte/Electron/TypeScript app to Flutter, borrowing and improving Senpwai's structure and reusable infrastructure.

## Design

- For UI, component or theme work, read `DESIGN.md` first and follow its theme ownership and component contracts. Its layered Resend/Vercel direction is locked; implement surface depth and shared appearance through the theme layer.

## Migration approach

- The primary Flutter reference is `../senpwai/`(Sometimes called Sempy or Sempsth in writing). Inspect the relevant implementation before building an equivalent here.
- Follow its feature-oriented layout: domain features with models, repositories/services and Riverpod notifiers; shared infrastructure under `lib/shared/`; presentation under `lib/ui/`. Adapt and improve the boundaries for Sentorr rather than copying anime-specific assumptions or entire subsystems.
- Reuse suitable code, replacing Senpwai branding, package imports, storage paths and domain coupling. Sentorr must own its data and configuration independently.
- The original pre-migration Electron project lives in `Electron/`. Use `Electron/src/` as a reference for product behavior and logic. Preserve useful functionality while improving the implementation; Electron IPC and Svelte stores need Flutter-appropriate equivalents.

## Senpwai reuse pointers

Paths below are relative to `../senpwai/`. Read the relevant branch on demand rather than exploring the whole project every time.

| When working on                                              | Start with                                                                                                                                                                                                          |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Startup, initialization and lifecycle                        | `lib/main.dart`, `lib/ui/components/app_bootstrap.dart`, `lib/shared/app_lifecycle.dart`                                                                                                                            |
| Persistence/DAO concerns, settings and app directories       | `lib/shared/persistence/`, `lib/settings/{models,repository,notifier}.dart`, `lib/tracking/repository.dart`; file-backed repositories, serialized writes, corrupt-file recovery and secure storage                  |
| Dio setup, cookies, caching, cancellation and request limits | `lib/shared/net/`; inspect transport and interceptor dependencies before reuse                                                                                                                                      |
| Torrent/download management, queues and background work      | `lib/downloads/`; start with `manager.dart`, `models.dart`, `in_process_runtime.dart`, `isolate_runtime.dart` and `android_foreground_runtime.dart`; streaming and seek prioritization need Sentorr-specific design |
| Filename parsing and source matching                         | `lib/anitomy/anitomy.dart`, `lib/sources/shared/matcher/`, `lib/sources/shared/fuzzy.dart`; evaluate movie/TV filename handling separately                                                                          |
| Shared widgets, themes and desktop integration               | `lib/ui/components/`, `lib/ui/shared/theme/`, `lib/ui/shared/window_manager.dart`, `lib/ui/shared/desktop_tray_controller.dart`                                                                                     |
| Notifications and app updates                                | `lib/notifications/`, `lib/updates/`; adapt application identity, release sources and platform handling                                                                                                             |

## Owned dependencies

- `../libtorrent_dart/`: our Dart libtorrent bindings. Inspect its high-level API, examples and native build setup for torrent integration; we control the package and can extend it when needed.
- `../anitomy_dart/`: our pure Dart release-filename parser. Inspect its API and parsing coverage before adapting it for Sentorr.
- Check the consuming `pubspec.yaml` to distinguish a published dependency from a local checkout; editing a sibling package alone does not update a published dependency.

## Existing Sentorr references

- Catalog/metadata: `Electron/src/backend/imdb/`. Torrent search, selection and streaming: `Electron/src/backend/torrent/`. Configuration: `Electron/src/backend/config/`. UI/player behavior: `Electron/src/renderer/src/`. Behavioral examples: `Electron/src/test/`.
- Playback work: consult `tool/codec_lab/README.md` and `tool/codec_lab/VALIDATION.md`, then its Flutter code. This MediaKit prototype covers local-file playback; it does not establish torrent streaming support. Check the recorded native-library findings before making codec compatibility claims.

## Misc
- Keep files thin and focused instead of owning a lot of functionality, break down most things that go over 300 lines into smaller components unless justified.
- When asked to commit use concise clear messages e.g., "Add home page" and no co-authored-by.
