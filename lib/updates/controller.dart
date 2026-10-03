import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

import 'restore.dart';

import '../app/services.dart';
import '../settings/notifier.dart';
import 'manifest_repository.dart';
import 'macos_update_bridge.dart';
import 'models.dart';
import 'platform_installer.dart';
import 'transfer.dart';
import 'update_repository.dart';

final updatesProvider = NotifierProvider<UpdateController, UpdateState>(
  UpdateController.new,
);
const _channel = String.fromEnvironment(
  'UPDATE_CHANNEL',
  defaultValue: 'stable',
);

class UpdateController extends Notifier<UpdateState> {
  final _mac = const MacOsUpdateBridge();
  UpdateRepository get _repository =>
      UpdateRepository(paths: ref.read(appPathsProvider));
  late UpdatePlatformInstaller _installer;
  CancelToken? _cancel;
  bool _busy = false;
  bool _disposed = false;

  @override
  UpdateState build() {
    _installer = UpdatePlatformInstaller.current();
    ref.listen(
      settingsProvider.select((s) => s.updates.automaticallyDownload),
      (_, enabled) {
        if (Platform.isMacOS) {
          unawaited(_mac.setAutomaticallyDownload(enabled));
        } else if (enabled && state.phase == UpdatePhase.available) {
          unawaited(download());
        }
      },
    );
    ref.onDispose(() {
      _disposed = true;
      _cancel?.cancel();
    });
    return const UpdateState();
  }

  Future<void> initialize() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (_disposed) return;
      state = state.copyWith(
        currentVersion: info.version,
        currentBuild: int.tryParse(info.buildNumber) ?? 0,
      );
      if (Platform.isMacOS) {
        final subscription = _mac.events.listen(_macEvent);
        ref.onDispose(() => unawaited(subscription.cancel()));
        await _mac.start(
          automaticallyDownload: ref
              .read(settingsProvider)
              .updates
              .automaticallyDownload,
        );
        return;
      }
      final restored = await restoreUpdate(
        repository: _repository,
        manifests: UpdateManifestRepository(
          paths: ref.read(appPathsProvider),
          dio: ref.read(networkClientProvider).dio,
        ),
        currentVersion: info.version,
        currentBuild: state.currentBuild,
        channels: _channel == 'prerelease'
            ? const {'stable', 'prerelease'}
            : const {'stable'},
      );
      if (_disposed) return;
      if (restored != null) {
        state = state.copyWith(
          phase: UpdatePhase.ready,
          release: restored.release,
          artifact: restored.artifact,
        );
        return;
      }
      await _repository.clearPrepared();
      await check(userInitiated: false);
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          phase: UpdatePhase.failed,
          error: error.toString(),
        );
      }
    }
  }

  Future<void> check({bool userInitiated = true}) async {
    if (_busy || state.phase == UpdatePhase.ready) return;
    _busy = true;
    state = state.copyWith(phase: UpdatePhase.checking, clearError: true);
    try {
      if (Platform.isMacOS) {
        await _mac.check();
        return;
      }
      final manifest = await UpdateManifestRepository(
        paths: ref.read(appPathsProvider),
        dio: ref.read(networkClientProvider).dio,
      ).fetch();
      if (_disposed) return;
      final candidate = manifest.latestCompatible(
        currentVersion: state.currentVersion,
        currentBuild: state.currentBuild,
        channels: _channel == 'prerelease'
            ? const {'stable', 'prerelease'}
            : const {'stable'},
      );
      state = state.copyWith(
        phase: candidate == null ? UpdatePhase.idle : UpdatePhase.available,
        release: candidate?.release,
        artifact: candidate?.artifact,
        clearError: true,
      );
      if (candidate != null &&
          ref.read(settingsProvider).updates.automaticallyDownload) {
        Future.microtask(download);
      }
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          phase: userInitiated ? UpdatePhase.failed : UpdatePhase.idle,
          error: userInitiated ? error.toString() : null,
          clearError: !userInitiated,
        );
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> download() async {
    if (_busy || state.phase != UpdatePhase.available) return;
    if (Platform.isMacOS) {
      await _mac.download();
      return;
    }
    final release = state.release!, artifact = state.artifact!;
    _busy = true;
    final cancel = _cancel = CancelToken();
    state = state.copyWith(phase: UpdatePhase.downloading, clearError: true);
    try {
      final file =
          await UpdateTransfer(
            ref.read(networkClientProvider).dio,
            _repository,
          ).download(
            release,
            artifact,
            cancelToken: cancel,
            onProgress: (n, total) {
              if (!_disposed) {
                state = state.copyWith(bytesReceived: n, totalBytes: total);
              }
            },
          );
      if (_disposed) return;
      await _repository.savePrepared(
        PreparedUpdate(
          version: release.version.toString(),
          build: release.build,
          artifact: artifact,
          filePath: file.path,
          platformPrepared: false,
        ),
      );
      state = state.copyWith(phase: UpdatePhase.ready);
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          phase: (error is DioException && CancelToken.isCancel(error))
              ? UpdatePhase.available
              : UpdatePhase.failed,
          error: (error is DioException && CancelToken.isCancel(error))
              ? null
              : error.toString(),
          clearError: (error is DioException && CancelToken.isCancel(error)),
        );
      }
    } finally {
      _busy = false;
      _cancel = null;
    }
  }

  void cancelDownload() {
    if (Platform.isMacOS) {
      unawaited(_mac.cancelDownload());
    } else {
      _cancel?.cancel();
    }
  }

  Future<UpdateInstallDisposition?> installAndRestart() async {
    if (_busy || state.phase != UpdatePhase.ready) return null;
    _busy = true;
    state = state.copyWith(phase: UpdatePhase.installing, clearError: true);
    try {
      if (Platform.isMacOS) {
        await _mac.installAndRestart();
        return UpdateInstallDisposition.applicationWillRestart;
      }
      final release = state.release!, artifact = state.artifact!;
      final file = _repository.artifactFile(artifact);
      await verifyArtifact(file, artifact);
      // Replacement is delayed until the viewer chooses Restart.
      await _installer.prepare(file, release);
      final disposition = await _installer.installAndRestart(file, release);
      if (disposition == UpdateInstallDisposition.externalInstallerOpened) {
        state = state.copyWith(phase: UpdatePhase.ready);
      }
      return disposition;
    } catch (error) {
      state = state.copyWith(
        phase: UpdatePhase.failed,
        error: error.toString(),
      );
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> retry() async {
    if (state.release != null) {
      state = state.copyWith(phase: UpdatePhase.available);
      await download();
    } else {
      await check();
    }
  }

  void _macEvent(Map<String, Object?> event) {
    if (_disposed) return;
    final phase = UpdatePhase.values.firstWhere(
      (p) => p.name == event['phase'],
      orElse: () => UpdatePhase.idle,
    );
    final version = event['version'] as String?;
    state = state.copyWith(
      phase: phase,
      release: version == null
          ? null
          : AppRelease(
              version: Version.parse(version),
              build: int.tryParse(event['build'].toString()) ?? 0,
              channel: _channel,
              mandatory: false,
              notes: event['notes'] as String? ?? '',
              artifacts: const [],
            ),
      bytesReceived: (event['bytesReceived'] as num?)?.toInt() ?? 0,
      totalBytes: (event['totalBytes'] as num?)?.toInt() ?? 0,
      error: event['error'] as String?,
      clearError: event['error'] == null,
    );
  }
}
