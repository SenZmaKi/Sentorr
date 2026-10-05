import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'file_response.dart';
import 'identity.dart';
import 'models.dart';

final _log = Logger('sentorr.sync.server');

/// The port a device listens on when it is free, so an address typed by
/// hand stays right across launches.
const preferredSyncPort = 47615;

/// Tells the other side which port this device listens on, since the
/// connection comes from another.
const syncPortHeader = 'x-sentorr-port';

/// A request the server refuses with [message] for the viewer, e.g. a
/// pairing attempt while pairing is closed.
class SyncRefusal implements Exception {
  const SyncRefusal(this.message, {this.status = HttpStatus.conflict});
  final String message;
  final int status;

  @override
  String toString() => message;
}

/// What the server answers with. Pairing comes from devices not yet
/// trusted; everything else only from a paired device's certificate.
abstract interface class SyncRoutes {
  Future<Map<String, dynamic>> pairStart(Map<String, dynamic> body);
  Future<Map<String, dynamic>> pairReveal(Map<String, dynamic> body);
  Future<Map<String, dynamic>> pairConfirm(
    Map<String, dynamic> body,
    DeviceAddress from,
  );

  /// The paired device with this certificate fingerprint, if any.
  PairedDevice? paired(String fingerprint);

  /// [device] reached this one from [address].
  void seen(PairedDevice device, DeviceAddress address);
  Future<Map<String, dynamic>> sync(
    PairedDevice device,
    Map<String, dynamic> body,
  );

  /// What this device shares: finished files and downloads under way.
  FutureOr<Map<String, dynamic>> library(PairedDevice device);
  File? media(PairedDevice device, String itemId);
}

/// HTTPS on every interface, presenting this device's certificate and
/// asking callers for theirs.
class SyncServer {
  SyncServer(this.identity, this.routes);
  final DeviceIdentity identity;
  final SyncRoutes routes;
  late final SecurityContext _context = identity.context();
  HttpServer? _server;

  int get port => _server?.port ?? 0;

  Future<void> start(Iterable<String> trusted) async {
    for (final pem in trusted) {
      trust(pem);
    }
    _server = await _bind(preferredSyncPort).catchError((Object _) => _bind(0));
    _log.info('Listening on port $port');
    _server!.listen((r) => unawaited(_handle(r)));
  }

  /// Lets [certificatePem]'s holder complete the TLS handshake. Whether it
  /// is still paired is checked on every request, so nothing is untrusted.
  void trust(String certificatePem) =>
      _context.setTrustedCertificatesBytes(utf8.encode(certificatePem));

  Future<HttpServer> _bind(int port) async {
    try {
      return await HttpServer.bindSecure(
        InternetAddress.anyIPv6,
        port,
        _context,
        requestClientCertificate: true,
      );
    } on SocketException {
      // No IPv6 on this host.
      return HttpServer.bindSecure(
        InternetAddress.anyIPv4,
        port,
        _context,
        requestClientCertificate: true,
      );
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.pathSegments;
    try {
      if (path.length == 3 && path[0] == 'v1' && path[1] == 'pair') {
        return await _pair(request, path[2]);
      }
      final certificate = request.certificate;
      final device = certificate == null
          ? null
          : routes.paired(fingerprintOfDer(certificate.der));
      if (device == null) {
        throw const SyncRefusal(
          'Not paired with this device',
          status: HttpStatus.forbidden,
        );
      }
      routes.seen(device, _from(request));
      switch ((request.method, path)) {
        case ('POST', ['v1', 'sync']):
          await _json(request, await routes.sync(device, await _body(request)));
        case ('GET', ['v1', 'library']):
          final library = await routes.library(device);
          if (routes.paired(device.fingerprint) == null) {
            throw const SyncRefusal(
              'Not paired with this device',
              status: HttpStatus.forbidden,
            );
          }
          if (library['revision'] != null &&
              request.headers.value('x-sentorr-library-revision') ==
                  library['revision']) {
            await _json(request, {
              'revision': library['revision'],
              'unchanged': true,
              'downloads': library['downloads'],
            });
          } else {
            await _json(request, library);
          }
        case ('GET' || 'HEAD', ['v1', 'media', final id]):
          final file = routes.media(device, id);
          if (file == null || !await file.exists()) {
            throw const SyncRefusal('Gone', status: HttpStatus.notFound);
          }
          await sendFile(request, file);
        default:
          throw const SyncRefusal('Unknown', status: HttpStatus.notFound);
      }
    } on SyncRefusal catch (refusal) {
      await _error(request, refusal.status, refusal.message);
    } catch (error, stack) {
      _log.warning(
        '${request.method} ${request.uri.path} failed',
        error,
        stack,
      );
      await _error(request, HttpStatus.internalServerError, 'Failed');
    }
  }

  Future<void> _pair(HttpRequest request, String step) async {
    if (request.method != 'POST') {
      throw const SyncRefusal('Use POST', status: HttpStatus.methodNotAllowed);
    }
    final body = await _body(request);
    await _json(request, switch (step) {
      'start' => await routes.pairStart(body),
      'reveal' => await routes.pairReveal(body),
      'confirm' => await routes.pairConfirm(body, _from(request)),
      _ => throw const SyncRefusal('Unknown', status: HttpStatus.notFound),
    });
  }

  DeviceAddress _from(HttpRequest request) {
    final remote = request.connectionInfo!.remoteAddress;
    // A v4 caller of a dual-stack socket arrives as ::ffff:a.b.c.d.
    final host = remote.address.startsWith('::ffff:')
        ? remote.address.substring(7)
        : remote.address;
    final port = int.tryParse(request.headers.value(syncPortHeader) ?? '');
    return (host: host, port: port ?? preferredSyncPort);
  }

  /// Sync state is small; anything this large is not one.
  static const _maxBody = 16 << 20;

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > _maxBody) {
        throw const SyncRefusal('Too large', status: HttpStatus.badRequest);
      }
    }
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) {
      throw const SyncRefusal('Expected an object', status: 400);
    }
    return json;
  }

  Future<void> _json(HttpRequest request, Object body) {
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    return request.response.close();
  }

  Future<void> _error(HttpRequest request, int status, String message) async {
    try {
      request.response.statusCode = status;
      await _json(request, {'error': message});
    } catch (_) {
      // The response had already started.
    }
  }

  Future<void> close() async => _server?.close(force: true);
}
