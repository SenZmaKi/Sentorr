import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../watch_backup.dart';
import 'drive_auth.dart';

/// Google Play services owns token persistence and renewal on Android.
/// Only the connection preference is persisted by the native bridge.
class AndroidDriveAuth extends DriveAuth {
  AndroidDriveAuth({
    required super.dio,
    this.channel = const MethodChannel('sentorr/drive_auth'),
  }) : super(openBrowser: _unusedBrowser);

  final MethodChannel channel;
  static final _log = Logger('sentorr.backup.android_auth');
  bool _connected = false;
  String? _token;
  Future<String>? _authorizing;
  int _generation = 0;

  static Future<bool> _unusedBrowser(Uri _) async => false;

  @override
  bool get connected => _connected;

  @override
  Future<bool> restore() async {
    _connected = await channel.invokeMethod<bool>('restore') ?? false;
    return _connected;
  }

  @override
  Future<void> connect() async {
    await _authorize(interactive: true);
  }

  @override
  Future<String> accessToken() {
    if (!_connected) {
      throw const BackupException('Google Drive is not connected.');
    }
    // The SDK checks its cache and renews expired tokens without a prompt.
    return _authorize(interactive: false);
  }

  @override
  Future<String> refresh() => _authorize(interactive: false, invalidate: true);

  Future<String> _authorize({
    required bool interactive,
    bool invalidate = false,
  }) {
    return _authorizing ??= _request(interactive, invalidate).whenComplete(() {
      _authorizing = null;
    });
  }

  Future<String> _request(bool interactive, bool invalidate) async {
    final generation = _generation;
    try {
      final token = await channel.invokeMethod<String>('authorize', {
        'interactive': interactive,
        if (invalidate && _token != null) 'invalidateToken': _token,
      });
      if (generation != _generation) {
        throw const BackupException('Google Drive was disconnected.');
      }
      if (token == null || token.isEmpty) {
        throw const BackupException('Google sent back no Drive access.');
      }
      _token = token;
      _connected = true;
      return token;
    } on PlatformException catch (error) {
      _log.warning('Native Drive authorization failed: ${error.code}');
      if (error.code == 'reauthorize_required' ||
          error.code == 'missing_access') {
        _connected = false;
      }
      throw BackupException(error.message ?? 'Google Drive sign-in failed.');
    }
  }

  @override
  Future<void> disconnect() async {
    // After a restart, obtain the already-granted token silently so
    // disconnect can revoke access as well as clear the local preference.
    if (_connected && _token == null && _authorizing == null) {
      try {
        await _authorize(interactive: false);
      } on Object {
        // Clearing the local connection must still work while offline.
      }
    }
    _generation++;
    // Wait for an outstanding request so it cannot restore native connection
    // state after the viewer disconnects.
    try {
      await _authorizing;
    } on Object {
      /* Already disconnected locally. */
    }
    final token = _token;
    _connected = false;
    _token = null;
    await channel.invokeMethod<void>('forget', {'token': token});
    if (token == null) return;
    try {
      await dio.post<void>(
        revokeEndpoint,
        data: {'token': token},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } on DioException catch (error) {
      _log.info(
        'Drive disconnected locally; revoke failed: ${error.type.name}',
      );
    }
  }
}
