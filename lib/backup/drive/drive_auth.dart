import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import '../../shared/persistence/credential_store.dart';
import '../watch_backup.dart';
import 'drive_config.dart';
import 'sign_in_page.dart';

final _log = Logger('sentorr.backup.auth');

/// Signs in to Google with the system browser and keeps the access it
/// grants: PKCE with a loopback redirect, the flow Google offers every
/// desktop and mobile app without a platform SDK.
class DriveAuth {
  DriveAuth({
    required this.dio,
    this.credentials,
    required this.openBrowser,
    this.bringBack,
    this.returnLink,
    this.clientId = driveClientId,
    this.clientSecret = driveClientSecret,
    this.authorizeEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth',
    this.tokenEndpoint = 'https://oauth2.googleapis.com/token',
    this.revokeEndpoint = 'https://oauth2.googleapis.com/revoke',
    this.signInTimeout = const Duration(minutes: 5),
  });

  final Dio dio;

  /// Without it, as in debug builds, the sign-in lasts until the app closes.
  final CredentialStore? credentials;
  final Future<bool> Function(Uri url) openBrowser;

  /// Brings the app back in front of the browser once Google answers.
  final Future<void> Function()? bringBack;

  /// A link the sign-in page follows back to the app, where the app cannot
  /// come forward itself, as on Android.
  final String? returnLink;
  final String clientId, clientSecret;
  final String authorizeEndpoint, tokenEndpoint, revokeEndpoint;
  final Duration signInTimeout;

  String? _refreshToken, _accessToken;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);

  bool get connected => _refreshToken != null;

  /// Picks up a sign-in saved earlier; true when there was one.
  Future<bool> restore() async {
    _refreshToken ??= await credentials?.readDriveToken();
    return connected;
  }

  /// Opens Google's consent page and waits for the viewer to finish it.
  Future<void> connect() async {
    final verifier = _random(64);
    final state = _random(24);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final redirect = 'http://127.0.0.1:${server.port}';
      final code = _waitForCode(server, state);
      final opened = await openBrowser(
        Uri.parse(authorizeEndpoint).replace(
          queryParameters: {
            'client_id': clientId,
            'redirect_uri': redirect,
            'response_type': 'code',
            'scope': driveScope,
            'state': state,
            'code_challenge': _challenge(verifier),
            'code_challenge_method': 'S256',
            // Without both, Google withholds the refresh token on a repeat
            // sign-in.
            'access_type': 'offline',
            'prompt': 'consent',
          },
        ),
      );
      if (!opened) {
        throw const BackupException('Could not open the browser to sign in.');
      }
      final granted = await code.timeout(
        signInTimeout,
        onTimeout: () => throw const BackupException('Sign-in timed out.'),
      );
      await _grant({
        'grant_type': 'authorization_code',
        'code': granted,
        'redirect_uri': redirect,
        'code_verifier': verifier,
      });
    } finally {
      await server.close(force: true);
    }
  }

  /// A token that is good for the next request; refreshes when needed.
  Future<String> accessToken() async {
    final held = _accessToken;
    if (held != null && DateTime.now().isBefore(_expires)) return held;
    return refresh();
  }

  /// Gets a fresh token. A refusal means the viewer revoked access, which
  /// signs out.
  Future<String> refresh() async {
    final token = _refreshToken;
    if (token == null) {
      throw const BackupException('Google Drive is not connected.');
    }
    try {
      await _grant({'grant_type': 'refresh_token', 'refresh_token': token});
    } on DioException catch (error) {
      if (error.response?.statusCode == 400 ||
          error.response?.statusCode == 401) {
        _log.warning('Google refused the saved sign-in; signing out');
        await _forget();
        throw const BackupException(
          'Google Drive access was removed. Connect again to continue.',
        );
      }
      rethrow;
    }
    return _accessToken!;
  }

  /// Signs out and tells Google to drop the access.
  Future<void> disconnect() async {
    final token = _refreshToken;
    await _forget();
    if (token == null) return;
    try {
      await dio.post<void>(
        revokeEndpoint,
        queryParameters: {'token': token},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } on DioException catch (error) {
      _log.info('Could not revoke the Drive token: $error');
    }
  }

  Future<void> _grant(Map<String, String> form) async {
    final response = await dio.post<Map<String, dynamic>>(
      tokenEndpoint,
      data: {
        'client_id': clientId,
        if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
        ...form,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final json = response.data;
    final access = json?['access_token'];
    if (access is! String) {
      throw const BackupException('Google sent back no access.');
    }
    _accessToken = access;
    final seconds = json?['expires_in'];
    // A minute early, so a token never expires mid-request.
    _expires = DateTime.now().add(
      Duration(seconds: (seconds is int ? seconds : 3600) - 60),
    );
    final refresh = json?['refresh_token'];
    if (refresh is String && refresh.isNotEmpty) {
      _refreshToken = refresh;
      await _save(refresh);
    }
  }

  Future<void> _save(String token) async {
    try {
      await credentials?.writeDriveToken(token);
    } catch (error, stack) {
      // Signed in for now; the viewer signs in again next launch.
      _log.warning('Could not keep the Drive token', error, stack);
    }
  }

  Future<void> _forget() async {
    _refreshToken = _accessToken = null;
    try {
      await credentials?.deleteDriveToken();
    } catch (error, stack) {
      _log.warning('Could not delete the Drive token', error, stack);
    }
  }

  /// The code Google redirects the browser to us with, for our [state].
  Future<String> _waitForCode(HttpServer server, String state) {
    final done = Completer<String>();
    server.listen((request) async {
      final query = request.uri.queryParameters;
      final mine = query['state'] == state;
      final code = query['code'];
      final failed = query['error'];
      // Browsers also ask for a favicon, and strangers may knock.
      if (!mine || (code == null && failed == null)) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        signInPage(signedIn: code != null, returnLink: returnLink),
      );
      await request.response.close();
      if (done.isCompleted) return;
      unawaited(
        bringBack?.call().catchError((Object error) {
          _log.fine('Could not bring the window back: $error');
        }),
      );
      if (code == null) {
        done.completeError(const BackupException('Sign-in was cancelled.'));
      } else {
        done.complete(code);
      }
    });
    return done.future;
  }

  static final _secure = Random.secure();

  static String _random(int length) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    return List.generate(
      length,
      (_) => alphabet[_secure.nextInt(alphabet.length)],
    ).join();
  }

  static String _challenge(String verifier) => base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');
}
