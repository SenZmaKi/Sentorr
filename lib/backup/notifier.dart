import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/services.dart';
import '../shared/persistence/credential_store.dart';
import '../settings/notifier.dart';
import '../shared/app_lifecycle.dart';
import '../ui/shared/window_manager.dart';
import 'backup_data.dart';
import 'drive/drive_auth.dart';
import 'drive/drive_client.dart';
import 'drive/drive_config.dart';
import 'drive/sign_in_page.dart';
import 'file_backup.dart';
import 'remote.dart';
import 'watch_backup.dart';

final _log = Logger('sentorr.backup');

/// The keychain, absent in debug builds and tests.
final credentialStoreProvider = Provider<CredentialStore?>((ref) => null);

final driveAuthProvider = Provider<DriveAuth>(
  (ref) => DriveAuth(
    dio: ref.watch(networkClientProvider).dio,
    credentials: ref.watch(credentialStoreProvider),
    openBrowser: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
    // As Senpwai does after AniList: back to the app once Google answers.
    bringBack: WindowManager.getInstance().focus,
    returnLink: Platform.isAndroid ? androidReturnLink : null,
  ),
);

final backupRemoteProvider = Provider<BackupRemote>(
  (ref) => DriveBackupClient(
    dio: ref.watch(networkClientProvider).dio,
    auth: ref.watch(driveAuthProvider),
  ),
);

class BackupState {
  const BackupState({
    this.connected = false,
    this.busy = false,
    this.lastBackup,
    this.error,
  });

  final bool connected, busy;

  /// When Drive last matched this device.
  final DateTime? lastBackup;

  /// Why the last attempt failed, for the viewer.
  final String? error;

  BackupState copyWith({
    bool? connected,
    bool? busy,
    DateTime? lastBackup,
    String? Function()? error,
  }) => BackupState(
    connected: connected ?? this.connected,
    busy: busy ?? this.busy,
    lastBackup: lastBackup ?? this.lastBackup,
    error: error == null ? this.error : error(),
  );
}

final backupProvider = NotifierProvider<BackupNotifier, BackupState>(
  BackupNotifier.new,
);

/// Backs up what the viewer would miss on a new device, to a file or to
/// Google Drive. Once Drive is connected it syncs at launch and then every
/// [BackupSettings.interval].
class BackupNotifier extends Notifier<BackupState> {
  static const _attempts = 3;

  /// Leaving and returning to the app sync only when the last sync is older.
  static const _staleAfter = Duration(minutes: 10);

  Timer? _timer;

  @override
  BackupState build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(settingsProvider.select((s) => s.backup.interval), (_, _) {
      if (state.connected) _arm();
    });
    // Leaving pushes what was watched here; coming back pulls what was
    // watched elsewhere, so a switch between devices finds them in step.
    ref.listen(AppLifecycleNotifier.provider, (_, now) {
      final left =
          now == AppLifecycleState.paused || now == AppLifecycleState.hidden;
      if (left || now == AppLifecycleState.resumed) _syncIfStale();
    });
    return const BackupState();
  }

  /// Picks up a Drive sign-in from an earlier run and syncs with it.
  Future<void> initialize() async {
    if (!driveConfigured || !await ref.read(driveAuthProvider).restore()) {
      return;
    }
    state = state.copyWith(connected: true);
    _arm();
    await syncNow();
  }

  Future<void> connect() => _run(() async {
    await ref.read(driveAuthProvider).connect();
    state = state.copyWith(connected: true);
    _arm();
    await _sync();
  });

  Future<void> disconnect() async {
    _timer?.cancel();
    await ref.read(driveAuthProvider).disconnect();
    state = const BackupState();
  }

  /// Merges Drive's copy into this device and backs the result up.
  Future<void> syncNow() => _run(_sync);

  /// Saves the history to a file. False when the viewer cancelled.
  Future<bool> exportFile() async {
    state = state.copyWith(error: () => null);
    try {
      return await FileBackup.export(ref.read(backupDataProvider).current());
    } catch (error, stack) {
      _fail(error, stack);
      return false;
    }
  }

  /// Merges a backup file into the app. False when the viewer cancelled or
  /// the file was no good.
  Future<bool> importFile() async {
    state = state.copyWith(error: () => null);
    try {
      final backup = await FileBackup.import();
      if (backup == null) return false;
      await ref.read(backupDataProvider).apply(backup);
      return true;
    } catch (error, stack) {
      _fail(error, stack);
      return false;
    }
  }

  /// Brings this device and the backup level with each other: merge what
  /// the backup holds into the app, then replace the backup with the
  /// result. Merging only ever adds, and every device pushes what it has
  /// merged, so devices converge whatever the order they sync in. If
  /// another device replaces the backup in between, merge again.
  Future<void> _sync() async {
    final remote = ref.read(backupRemoteProvider);
    final data = ref.read(backupDataProvider);
    for (var attempt = 0; attempt < _attempts; attempt++) {
      final held = await remote.download();
      if (held != null) await data.apply(held.bundle);
      final merged = data.current();
      if (held == null || !merged.matches(held.bundle)) {
        try {
          await remote.upload(merged, basedOn: held?.revision);
        } on BackupConflict {
          continue;
        }
      }
      state = state.copyWith(lastBackup: DateTime.now(), error: () => null);
      return;
    }
    throw const BackupException(
      'Google Drive keeps changing. It will try again soon.',
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (state.busy) return;
    state = state.copyWith(busy: true, error: () => null);
    try {
      await action();
    } catch (error, stack) {
      _fail(error, stack);
    } finally {
      // Signed out meanwhile, as when Google drops the access.
      state = state.copyWith(
        busy: false,
        connected: ref.read(driveAuthProvider).connected,
      );
    }
  }

  void _syncIfStale() {
    final last = state.lastBackup;
    if (!state.connected || state.busy) return;
    if (last == null || DateTime.now().difference(last) > _staleAfter) {
      unawaited(syncNow());
    }
  }

  /// Syncs every [BackupSettings.interval] from now, replacing any timer.
  void _arm() {
    _timer?.cancel();
    _timer = Timer.periodic(ref.read(settingsProvider).backup.interval, (_) {
      if (state.connected) unawaited(syncNow());
    });
  }

  void _fail(Object error, StackTrace stack) {
    _log.warning('Backup failed', error, stack);
    state = state.copyWith(
      error: () => switch (error) {
        BackupException() => error.message,
        DioException(:final response?) =>
          'Google Drive refused the request (${response.statusCode}).',
        DioException() => 'Could not reach Google Drive.',
        _ => 'The backup did not work.',
      },
    );
  }
}
