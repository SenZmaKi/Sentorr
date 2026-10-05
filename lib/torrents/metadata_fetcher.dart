import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import 'models.dart';
import 'parsing.dart';

/// Downloads only the chosen release's metadata through the shared transport.
/// A cache miss is a release failure; magnets are never opened here.
class TorrentMetadataFetcher {
  TorrentMetadataFetcher(this.dio);
  final Dio dio;
  static const maxBytes = 8 * 1024 * 1024;
  static const requestTimeout = Duration(seconds: 15);
  static final _log = Logger('sentorr.torrents.metadata');

  Future<Uint8List> fetch(TorrentRelease release, CancelToken cancel) async {
    if (infoHash(release.infoHash) == null) {
      throw const SourceException('Invalid torrent info hash');
    }
    final cache = torrentCacheUrl(release.infoHash);
    final urls = {...release.torrentUrls.where((url) => url != cache), cache};
    Object? lastError;
    for (final url in urls) {
      _checkCancelled(cancel);
      if (torrentHttpUrl(url.toString(), url) == null) continue;
      final token = CancelToken();
      unawaited(cancel.whenCancel.then((error) => token.cancel(error)));
      final clock = Stopwatch()..start();
      try {
        final bytes = await _download(url, token).timeout(requestTimeout);
        _checkCancelled(cancel);
        _log.info(
          '${release.infoHash}: ${bytes.length} metadata bytes from '
          '${url.host} in ${clock.elapsedMilliseconds}ms',
        );
        return bytes;
      } on DioException catch (error) {
        _checkCancelled(cancel);
        if (CancelToken.isCancel(error)) rethrow;
        lastError = error;
        _log.fine('Metadata download failed from ${url.host}', error);
      } on TimeoutException catch (error) {
        lastError = error;
        _log.fine('Metadata download timed out from ${url.host}', error);
      } on SourceException catch (error) {
        lastError = error;
        _log.fine('Invalid metadata response from ${url.host}', error);
      } finally {
        token.cancel('Metadata request finished');
      }
    }
    _checkCancelled(cancel);
    throw SourceException('Could not download torrent metadata: $lastError');
  }

  void _checkCancelled(CancelToken token) {
    if (token.isCancelled) throw token.cancelError!;
  }

  Future<Uint8List> _download(Uri url, CancelToken cancel) async {
    final response = await dio.getUri<ResponseBody>(
      url,
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'application/x-bittorrent, application/octet-stream',
        },
        sendTimeout: requestTimeout,
        receiveTimeout: requestTimeout,
      ),
    );
    final body = response.data;
    if (response.statusCode != 200 || body == null) {
      throw SourceException('Metadata HTTP ${response.statusCode}');
    }
    final output = BytesBuilder(copy: false);
    final reader = StreamIterator(body.stream);
    final cancelled = cancel.whenCancel.then<bool>((error) => throw error);
    // Bound actual received bytes even when Content-Length is absent or false.
    try {
      while (await Future.any([reader.moveNext(), cancelled])) {
        _checkCancelled(cancel);
        final chunk = reader.current;
        if (output.length + chunk.length > maxBytes) {
          throw const SourceException('Torrent metadata exceeds 8 MiB');
        }
        output.add(chunk);
      }
    } finally {
      await reader.cancel();
    }
    _checkCancelled(cancel);
    final bytes = output.takeBytes();
    if (bytes.isEmpty || bytes.first != 0x64 || bytes.last != 0x65) {
      throw const SourceException('Response is not a torrent dictionary');
    }
    // Native parsing and the expected hash check happen before engine.add
    // creates storage. HTTP success alone never establishes torrent identity.
    return bytes;
  }
}
