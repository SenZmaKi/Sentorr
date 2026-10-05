import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';

final _log = Logger('sentorr.credentials');

typedef ProxyCredentials = ({String username, String password});

/// Secrets kept in the system keychain rather than the settings file.
class CredentialStore {
  CredentialStore([
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: true,
        preferencesKeyPrefix: 'sentorr_',
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
        synchronizable: false,
      ),
      mOptions: MacOsOptions(
        accountName: 'com.sentorr.sentorr.credentials',
        accessibility: KeychainAccessibility.unlocked_this_device,
        synchronizable: false,
        label: 'Sentorr credentials',
        description: 'Credentials saved by Sentorr',
        usesDataProtectionKeychain: false,
      ),
    ),
  ]);

  final FlutterSecureStorage _storage;
  static const _proxyKey = 'torrent_proxy_credentials';
  static const _driveKey = 'google_drive_refresh_token';

  /// Null when none is saved or the keychain cannot be read.
  Future<String?> readDriveToken() async {
    try {
      final token = await _storage.read(key: _driveKey);
      return token == null || token.isEmpty ? null : token;
    } on PlatformException catch (error, stack) {
      _log.warning('Could not read the Drive token', error, stack);
      return null;
    }
  }

  Future<void> writeDriveToken(String token) =>
      _storage.write(key: _driveKey, value: token);

  Future<void> deleteDriveToken() => _storage.delete(key: _driveKey);

  /// Null when none are saved or the keychain cannot be read; a corrupt
  /// entry is deleted.
  Future<ProxyCredentials?> readProxy() async {
    try {
      final encoded = await _storage.read(key: _proxyKey);
      if (encoded == null || encoded.isEmpty) return null;
      final json = jsonDecode(encoded);
      if (json case {
        'username': final String username,
        'password': final String password,
      }) {
        return (username: username, password: password);
      }
      throw const FormatException('Expected a username and password');
    } on FormatException catch (error, stack) {
      _log.warning('Deleting corrupt proxy credentials', error, stack);
      await _storage.delete(key: _proxyKey);
    } on PlatformException catch (error, stack) {
      _log.warning('Could not read proxy credentials', error, stack);
    }
    return null;
  }

  Future<void> writeProxy(ProxyCredentials credentials) {
    if (credentials.username.isEmpty && credentials.password.isEmpty) {
      return _storage.delete(key: _proxyKey);
    }
    return _storage.write(
      key: _proxyKey,
      value: jsonEncode({
        'username': credentials.username,
        'password': credentials.password,
      }),
    );
  }
}
