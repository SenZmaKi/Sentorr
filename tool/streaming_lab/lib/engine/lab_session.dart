import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:path/path.dart' as p;

import 'cancellation.dart';
import 'media_server.dart';
import 'media_bootstrap.dart';
import 'native_session.dart';
import 'torrent_bytes.dart';
import 'streaming_policy.dart';
import 'acquisition_diagnostics.dart';

/// One experiment. Seed and downloader both live in the same engine isolate.
class LabSession {
  LabSession(this.onEvent);
  final void Function(Map<String, Object?>) onEvent;
  NativeSession? native, seedNative;
  TorrentHandle? torrent, seed;
  Directory? directory;
  MediaServer? server;
  TorrentBytes? bytes;
  int _readAheadBytes = 16 * 1024 * 1024;
  Timer? _monitor;
  StreamSubscription<AlertInfo>? _alerts;
  final lifetime = Cancellation();
  List<TorrentFileEntry> files = [];
  bool _closed = false;
  String mode = '';

  Future<List<Map<String, Object?>>> open(
    String input, {
    bool controlled = false,
    int downloadMbps = 40,
    int readAheadMiB = 16,
  }) async {
    mode = controlled ? 'Controlled local seed' : 'External torrent';
    directory = await Directory.systemTemp.createTemp('sentorr-streaming-');
    native = NativeSession(local: controlled);
    _alerts = native!.events.listen(
      (alert) {
        if (alert.what != 'read_piece' && alert.what != 'piece_finished') {
          onEvent({
            'event': 'native',
            'kind': alert.what,
            'message': alert.message,
          });
        }
      },
      onError: (Object error) =>
          onEvent({'event': 'error', 'message': '$error'}),
    );
    final target = await Directory(p.join(directory!.path, 'download'))
        .create();
    if (controlled) {
      final seedRoot = await Directory(p.join(directory!.path, 'seed'))
          .create();
      final source = File(input);
      final copy = await source.copy(p.join(seedRoot.path, p.basename(input)));
      lifetime.check();
      final data = createTorrentData(
        sourcePath: copy.path,
        pieceSize:
            int.tryParse(
              Platform.environment['STREAMING_CONTROLLED_PIECE_BYTES'] ?? '',
            ) ??
            128 * 1024,
      );
      seedNative = NativeSession(local: true);
      seed = seedNative!.session.addTorrentData(
        torrentData: data,
        savePath: seedRoot.path,
      );
      seed!.unsetFlags(
        LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
      );
      seed!.setUploadLimit(
        Platform.environment.containsKey('STREAMING_CONTROLLED_MBPS')
            ? 0
            : 256 * 1024,
      );
      await _until(
        () => seed!.getStatus().state == 5,
        'Local seed verification',
      );
      torrent = native!.session.addTorrentData(
        torrentData: data,
        savePath: target.path,
      );
    } else if (input.startsWith('magnet:')) {
      torrent = native!.session.addMagnet(
        magnetUri: input,
        savePath: target.path,
      );
    } else {
      torrent = native!.session.addTorrentFile(
        torrentPath: input,
        savePath: target.path,
      );
    }
    torrent!.setFlags(LibtorrentTorrentFlags.defaultDontDownload);
    torrent!.unsetFlags(
      LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
    );
    _readAheadBytes = readAheadMiB * 1024 * 1024;
    final controlledMbps = int.tryParse(
      Platform.environment['STREAMING_CONTROLLED_MBPS'] ?? '',
    );
    torrent!.setDownloadLimit(
      controlled
          ? controlledMbps == null
                ? 256 * 1024
                : controlledMbps * 1000000 ~/ 8
          : downloadMbps * 1000000 ~/ 8,
    );
    if (controlled) {
      await _until(
        () => seedNative!.session.listenPort > 0,
        'Seed listen port',
      );
      torrent!.connectPeer(
        address: '127.0.0.1',
        port: seedNative!.session.listenPort,
      );
    }
    _monitor = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _snapshot(),
    );
    await _until(() {
      try {
        files = torrent!.getFiles();
        return files.isNotEmpty;
      } catch (_) {
        return false;
      }
    }, 'Torrent metadata');
    // No file downloads without an active reader. Direct piece priorities also
    // allow pieces straddling a selected file boundary without fetching siblings.
    torrent!.prioritizeFiles(List.filled(files.length, 0));
    await _until(
      () => torrent!.getFilePriorities().every((p) => p == 0),
      'File priorities',
    );
    torrent!.prioritizePieces(List.filled(torrent!.numPieces, 0));
    return files
        .map(
          (f) => {
            'index': f.index,
            'path': f.path,
            'size': f.size,
            'offset': f.offset,
            'flags': f.flags,
          },
        )
        .toList();
  }

  Future<String> select(int index) async {
    if (bytes != null) {
      throw StateError('Stop the session before changing files');
    }
    final file = files.firstWhere((f) => f.index == index);
    if (file.size == 0 || (file.flags & 1) != 0) {
      throw StateError('Select a non-empty media file');
    }
    bytes = TorrentBytes(
      torrent!,
      file,
      (piece, cancellation) => native!.read(torrent!, piece, cancellation),
      readAheadBytes: _readAheadBytes,
    );
    if (StreamingPolicy.bootstrap) {
      await bootstrapMedia(bytes!, lifetime, onEvent);
    }
    server = MediaServer(bytes!, onEvent: onEvent);
    await server!.start();
    _snapshot();
    return server!.uri.toString();
  }

  void prepareSeek() => server?.cancelReads();
  void pauseTransfer(bool paused) {
    paused ? torrent!.pause() : torrent!.resume();
    onEvent({'event': 'transfer-pause', 'paused': paused});
  }

  void pauseSeed(bool paused) {
    if (seed == null) return;
    paused ? seed!.pause() : seed!.resume();
    if (!paused) {
      torrent!.connectPeer(
        address: '127.0.0.1',
        port: seedNative!.session.listenPort,
      );
    }
    if (!paused) {
      seed!.connectPeer(address: '127.0.0.1', port: native!.session.listenPort);
    }
    onEvent({'event': 'seed-pause', 'paused': paused});
  }

  void _snapshot() {
    if (_closed || torrent == null) return;
    try {
      final status = torrent!.getStatus();
      final source = bytes;
      final samples = <bool>[];
      if (source != null) {
        final first = source.file.offset ~/ source.pieceLength;
        final last =
            (source.file.offset + source.length - 1) ~/ source.pieceLength;
        final count = min(128, last - first + 1);
        for (var n = 0; n < count; n++) {
          samples.add(
            torrent!.havePiece(first + n * (last - first + 1) ~/ count),
          );
        }
      }
      onEvent({
        'event': 'snapshot',
        'mode': mode,
        'downloadRate': status.downloadRate,
        'payloadRate': status.downloadPayloadRate,
        'torrentState': status.state,
        'wantedBytes': status.totalWanted,
        'failedBytes': status.totalFailedBytes,
        'redundantBytes': status.totalRedundantBytes,
        'seeds': status.numSeeds,
        if (Platform.environment['STREAMING_AUDIT_DETAILS'] == '1')
          'acquisition': acquisitionDiagnostics(torrent!, seed),
        'peers': status.numPeers,
        'pieceLength': files.isEmpty ? null : torrent!.pieceLength,
        'totalDownloaded': status.totalDone,
        'fileBytes': source == null
            ? 0
            : torrent!.getFileProgress()[source.file.index],
        'fileSize': source?.length ?? 0,
        'pieceSamples': samples,
        'urgentPieces': source?.scheduler.urgentPieces ?? 0,
        'memoryCacheBytes': source?.cachedBytes ?? 0,
        'httpBytes': server?.servedBytes ?? 0,
        'requests': server?.requestCount ?? 0,
      });
    } catch (error) {
      onEvent({'event': 'error', 'message': '$error'});
    }
  }

  Future<void> _until(bool Function() ready, String operation) async {
    final watch = Stopwatch()..start();
    while (!ready()) {
      lifetime.check();
      if (watch.elapsed >
          Duration(
            seconds: operation == 'Torrent metadata'
                ? int.tryParse(
                        Platform.environment['STREAMING_METADATA_SECONDS'] ??
                            '',
                      ) ??
                      60
                : 60,
          )) {
        throw TimeoutException(operation);
      }
      await lifetime.wait(
        Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    lifetime.cancel();
    _monitor?.cancel();
    await server?.close();
    bytes?.close();
    await _alerts?.cancel();
    await native?.close();
    await seedNative?.close();
    // All native disk jobs finish during session destruction before cleanup.
    if (directory != null && await directory!.exists()) {
      await directory!.delete(recursive: true);
    }
  }
}
