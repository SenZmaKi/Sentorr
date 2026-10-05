import 'dart:convert';
import 'dart:io';

import 'identity.dart';
import 'models.dart';
import 'server.dart';

/// A request another device refused or could not answer.
class PeerException implements Exception {
  const PeerException(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// Talks to other devices' [SyncServer]s. Paired devices are pinned to
/// their certificate and see this device's; pairing trusts nothing yet and
/// reports which certificate the host presented.
class PeerClient {
  PeerClient(this.identity, {required this.port});
  final DeviceIdentity identity;

  /// Where this device listens, sent so the other can call back.
  final int Function() port;

  final _pinned = <String, HttpClient>{};
  HttpClient? _pairing;
  String? _presented;

  /// [path]'s JSON from the device holding [fingerprint] at [to].
  Future<Map<String, dynamic>> call(
    DeviceAddress to,
    String fingerprint,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final response = await open(
      to,
      fingerprint,
      path,
      body: body,
    ).timeout(timeout);
    return _decode(response).timeout(timeout);
  }

  /// The raw response, for media; [headers] are sent as given.
  Future<HttpClientResponse> open(
    DeviceAddress to,
    String fingerprint,
    String path, {
    Map<String, dynamic>? body,
    String method = 'GET',
    Map<String, String> headers = const {},
  }) async {
    final client = _pinned[fingerprint] ??=
        HttpClient(context: identity.context())
          ..connectionTimeout = const Duration(seconds: 5)
          ..badCertificateCallback = (certificate, _, _) =>
              fingerprintOfDer(certificate.der) == fingerprint;
    return _send(client, to, path, body, body == null ? method : 'POST', {
      ...headers,
      syncPortHeader: '${port()}',
    });
  }

  /// A pairing step at [to], answered with which certificate it presented.
  Future<({Map<String, dynamic> body, String fingerprint})> pair(
    DeviceAddress to,
    String step,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    // No certificate of ours: the host does not trust it yet.
    final client = _pairing ??=
        HttpClient(context: SecurityContext(withTrustedRoots: false))
          ..connectionTimeout = const Duration(seconds: 5)
          ..badCertificateCallback = (certificate, _, _) {
            _presented = fingerprintOfDer(certificate.der);
            return true;
          };
    final response = await _send(client, to, '/v1/pair/$step', body, 'POST', {
      syncPortHeader: '${port()}',
    }).timeout(timeout);
    final presented = response.certificate == null
        ? _presented
        : fingerprintOfDer(response.certificate!.der);
    final json = await _decode(response).timeout(timeout);
    if (presented == null) throw const PeerException('No certificate');
    return (body: json, fingerprint: presented);
  }

  Future<HttpClientResponse> _send(
    HttpClient client,
    DeviceAddress to,
    String path,
    Map<String, dynamic>? body,
    String method,
    Map<String, String> headers,
  ) async {
    final uri = Uri(scheme: 'https', host: to.host, port: to.port, path: path);
    try {
      final request = await client.openUrl(method, uri);
      headers.forEach(request.headers.set);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      return await request.close();
    } on SocketException catch (error) {
      throw PeerException("Couldn't reach the device (${error.message})");
    } on HttpException {
      // A server drops a certificate it does not trust mid-handshake.
      throw const PeerException(
        'The device closed the connection; it may no longer be paired',
      );
    } on HandshakeException {
      throw const PeerException(
        "The device's identity did not match, or it no longer trusts this one",
      );
    }
  }

  Future<Map<String, dynamic>> _decode(HttpClientResponse response) async {
    final text = await response.transform(utf8.decoder).join();
    final json = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 400) {
      throw PeerException(
        json is Map && json['error'] is String
            ? json['error'] as String
            : 'The device answered ${response.statusCode}',
        status: response.statusCode,
      );
    }
    if (json is! Map<String, dynamic>) {
      throw const PeerException('The device sent something unexpected');
    }
    return json;
  }

  /// Forgets [fingerprint]'s connections, e.g. once unpaired.
  void forget(String fingerprint) =>
      _pinned.remove(fingerprint)?.close(force: true);

  void close() {
    for (final client in _pinned.values) {
      client.close(force: true);
    }
    _pinned.clear();
    _pairing?.close(force: true);
  }
}
