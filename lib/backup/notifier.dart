import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/services.dart';
import '../sync/coordinator.dart';
import '../sync/user_state.dart';
import '../shared/persistence/credential_store.dart';
import '../settings/notifier.dart';
import '../shared/app_lifecycle.dart';
import '../ui/shared/window_manager.dart';
import 'backup_data.dart';
import 'drive/drive_auth.dart';
import 'drive/android_drive_auth.dart';
import 'drive/drive_client.dart';
import 'drive/drive_config.dart';
import 'file_backup.dart';
import 'remote.dart';
import 'watch_backup.dart';

final _log = Logger('sentorr.backup');

/// The keychain, absent in debug builds and tests.
final credentialStoreProvider = Provider<CredentialStore?>((ref) => null);

final driveAuthProvider = Provider<DriveAuth>((ref) {
  final dio = ref.watch(networkClientProvider).dio;
  if (Platform.isAndroid) return AndroidDriveAuth(dio: dio);
  return DriveAuth(
    dio: dio,
    credentials: ref.watch(credentialStoreProvider),
    openBrowser: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
    bringBack: WindowManager.getInstance().focus,
  );
});

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

  static const _publishDelay = Duration(minutes: 1);

  /// Backgrounding clean state only syncs when the last sync is older.
  static const _staleAfter = Duration(minutes: 10);

  late SyncCoordinator _coordinator;
  bool _dirty = false;
  int _changes = 0;
  int _generation = 0;

  @override
  BackupState build() {
    _coordinator = SyncCoordinator(
      action: () async {
        if (ref.read(driveAuthProvider).connected) await _perform(_sync);
      },
      active: () => ref.mounted,
    );
    ref.onDispose(_coordinator.dispose);
    ref.listen(settingsProvider.select((s) => s.backup.interval), (_, _) {
      if (state.connected) _arm();
    });
    void changed() {
      _dirty = true;
      _changes++;
      // A foreground desktop may keep playing for hours without a lifecycle
      // transition. Batch updates for a minute, including changes during an
      // upload, rather than repeatedly draining immediate follow-up passes.
      if (state.connected) {
        _coordinator.schedule(_publishDelay);
      }
    }

    ref.read(userStateSyncProvider).listen(ref, changed);
    // Leaving pushes what was watched here; coming back pulls what was
    // watched elsewhere, so a switch between devices finds them in step.
    ref.listen(AppLifecycleNotifier.provider, (_, now) {
      final left =
          now == AppLifecycleState.paused || now == AppLifecycleState.hidden;
      if (now == AppLifecycleState.resumed && state.connected) {
        // Local freshness says nothing about changes made on another device.
        unawaited(syncNow());
      } else if (left) {
        _syncIfStale();
      }
    });
    return const BackupState();
  }

  /// Picks up a Drive sign-in from an earlier run and syncs with it.
  Future<void> initialize() async {
    final generation = _generation;
    if (!driveConfigured || !await ref.read(driveAuthProvider).restore()) {
      return;
    }
    if (!ref.mounted || generation != _generation) return;
    state = state.copyWith(connected: true);
    _arm();
    await syncNow();
  }

  Future<void> connect() {
    final generation = ++_generation;
    // Authentication is an explicit action, not a coalescible sync pass. The
    // coordinator discards an overlapping run's first callback.
    return _perform(() async {
      await ref.read(driveAuthProvider).connect();
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(connected: true);
      _arm();
      await syncNow();
    });
  }

  Future<void> disconnect() async {
    final generation = ++_generation;
    _coordinator.stopRepeating();
    _coordinator.clearFollowUp();
    await ref.read(driveAuthProvider).disconnect();
    if (ref.mounted && generation == _generation) state = const BackupState();
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

  /// Pulls and merges the remote state, then publishes the result. Mutable
  /// backends can request a retry; Drive retains concurrent snapshots instead.
  /// Local changes during an upload schedule the next automatic batch;
  /// explicit overlapping sync requests still cause a follow-up pass.
  Future<void> _sync() async {
    final generation = _generation;
    bool valid() => ref.mounted && generation == _generation;
    final remote = ref.read(backupRemoteProvider);
    final data = ref.read(backupDataProvider);
    for (var attempt = 0; attempt < _attempts; attempt++) {
      if (!valid()) return;
      final RemoteBackup? held;
      try {
        held = await remote.download();
      } on BackupConflict {
        continue;
      }
      if (!valid()) return;
      if (held != null) await data.apply(held.bundle, valid: valid);
      if (!valid()) return;
      final merged = data.current();
      final changes = _changes;
      if (held == null ||
          held.needsPublication ||
          !merged.matches(held.bundle)) {
        try {
          await remote.upload(merged, basedOn: held?.revision);
        } on BackupConflict {
          continue;
        }
      }
      if (!valid()) return;
      _dirty = _changes != changes;
      state = state.copyWith(lastBackup: DateTime.now(), error: () => null);
      return;
    }
    throw const BackupException(
      'Google Drive keeps changing. It will try again soon.',
    );
  }

  Future<void> _run(Future<void> Function() action) =>
      _coordinator.run(first: () => _perform(action));

  Future<void> _perform(Future<void> Function() action) async {
    final generation = _generation;
    state = state.copyWith(busy: true, error: () => null);
    try {
      await action();
    } catch (error, stack) {
      if (ref.mounted && generation == _generation) _fail(error, stack);
      // Failed passes stop the drain; the next trigger retries normally.
      if (generation == _generation) _coordinator.clearFollowUp();
    } finally {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(
          busy: false,
          connected: ref.read(driveAuthProvider).connected,
        );
      }
    }
  }

  void _syncIfStale() {
    final last = state.lastBackup;
    if (!state.connected) return;
    if (_dirty ||
        last == null ||
        DateTime.now().difference(last) > _staleAfter) {
      unawaited(syncNow());
    }
  }

  /// Syncs every [BackupSettings.interval] from now, replacing any timer.
  void _arm() {
    _coordinator.repeat(ref.read(settingsProvider).backup.interval);
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
