import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';

import 'client.dart';
import 'models.dart';
import 'media_relay.dart';

final _log = Logger('sentorr.sync.proxy');

/// Where a paired device is and which certificate it must present.
typedef PeerRoute = ({DeviceAddress address, String fingerprint});

/// Hands the player a loopback URL for a file on another device. The
/// player cannot pin a self-signed certificate, so this forwards each
/// request, ranges included, over the pinned connection.
class MediaProxy {
  MediaProxy(this.client, this.route);
  final PeerClient client;

  /// The device's current route; null when it cannot be reached.
  final PeerRoute? Function(String deviceId) route;

  HttpServer? _server;
  late final String _token = List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((r) => unawaited(_forward(r)));
  }

  /// The player's URL for [itemId] on [deviceId]; null before [start].
  Uri? url(
    String deviceId,
    String itemId, {
    bool buffered = false,
    String? infoHash,
    String? fileVersion,
  }) => _server == null
      ? null
      : Uri.http('127.0.0.1:${_server!.port}', '/$_token/$deviceId/$itemId', {
          if (buffered) ...{'buffered': '1', 'hash': ?infoHash},
          'version': ?fileVersion,
        });

  Future<void> _forward(HttpRequest request) async {
    final response = request.response;
    final path = request.uri.pathSegments;
    final to = path.length == 3 && path[0] == _token ? route(path[1]) : null;
    if (to == null || (request.method != 'GET' && request.method != 'HEAD')) {
      response.statusCode = HttpStatus.notFound;
      return response.close();
    }
    final cancellation = PeerRequest();
    unawaited(
      response.done.then<void>(
        (_) => cancellation.cancel(),
        onError: (Object _) => cancellation.cancel(),
      ),
    );
    try {
      await ResumableMediaRelay(
        open: (headers, attempt) async {
          final latest = route(path[1]);
          if (latest == null) {
            throw const PeerException(
              'Device is no longer paired',
              status: 403,
            );
          }
          return client.open(
            latest.address,
            latest.fingerprint,
            '/v1/${request.uri.queryParameters['buffered'] == '1' ? 'buffered' : 'media'}/${path[2]}',
            method: request.method,
            cancellation: attempt,
            headers: headers,
          );
        },
      ).send(request, {
        if (request.uri.queryParameters['buffered'] == '1')
          'x-sentorr-torrent': request.uri.queryParameters['hash'] ?? '',
        if (request.uri.queryParameters['version'] case final version?)
          HttpHeaders.ifMatchHeader: '"$version"',
        HttpHeaders.rangeHeader: ?request.headers.value(
          HttpHeaders.rangeHeader,
        ),
      }, cancellation);
    } on PeerException catch (error) {
      _log.info('Peer media unavailable: $error');
      if (!cancellation.isCancelled) {
        try {
          response.statusCode = HttpStatus.badGateway;
          await response.close();
        } catch (_) {
          // A seek can close the player socket before headers are written.
        }
      }
    } catch (error) {
      _log.fine('Peer media request ended: $error');
      try {
        (await response.detachSocket(writeHeaders: false)).destroy();
      } catch (_) {
        // Already gone.
      }
    } finally {
      cancellation.cancel();
    }
  }

  Future<void> close() async => _server?.close(force: true);
}
