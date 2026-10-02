import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import '../config.dart';
import '../models.dart';
import 'cancellation.dart';
import 'media_bootstrap.dart';
import 'media_server.dart';
import 'native_session.dart';
import 'torrent_bytes.dart';

/// Worker-owned native/session/directory lifetime. No player or app dependencies.
class NativeHost {
  NativeHost(this.config, this.send);
  final TorrentStreamConfig config;
  final void Function(Map<String, Object?>) send;
  final lifetime = Cancellation();
  NativeSession? native;
  TorrentHandle? torrent;
  TorrentBytes? bytes;
  TorrentStatus? _lastStatus;
  TorrentFileEntry? _selectedFile;
  int _selectedBytes = 0;
  int _servedBytes = 0, _requests = 0;
  MediaServer? server;
  Directory? owned;

  /// The retained save directory, which outlives the session.
  Directory? saveDirectory;
  Timer? timer;
  StreamSubscription<AlertInfo>? alerts;
  List<TorrentFileEntry> files = [];
  List<Map> knownPeers = [];
  void addPeers(List peers) {
    if (torrent == null) throw StateError("No torrent open");
    for (final peer in peers) {
      if (knownPeers.length < 256 &&
          !knownPeers.any(
            (p) => p["address"] == peer["address"] && p["port"] == peer["port"],
          )) {
        knownPeers.add(Map.from(peer as Map));
      }
      torrent!.connectPeer(
        address: peer["address"] as String,
        port: peer["port"] as int,
      );
    }
  }

  TorrentStreamPhase phase = TorrentStreamPhase.idle;
  bool paused = false, closed = false;
  Map<String, Object?> fileMap(TorrentFileEntry f) => {
    'index': f.index,
    'path': f.path,
    'length': f.size,
    'pad': (f.flags & 1) != 0,
  };
  void snapshot() {
    final live = torrent != null;
    final status = live ? (_lastStatus = torrent!.getStatus()) : _lastStatus;
    if (bytes != null && live) {
      _selectedBytes = torrent!.getFileProgress()[bytes!.file.index];
    }
    _servedBytes = server?.servedBytes ?? _servedBytes;
    _requests = server?.requestCount ?? _requests;
    send({
      'kind': 'state',
      'value': {
        'phase': phase.index,
        'files': files.map(fileMap).toList(),
        'paused': paused,
        'rate': live ? (status?.downloadPayloadRate ?? 0).round() : 0,
        'uploadRate': live ? (status?.uploadPayloadRate ?? 0).round() : 0,
        'received': status?.totalPayloadDownload ?? 0,
        'uploaded': status?.totalPayloadUpload ?? 0,
        'torrentState': live ? status?.state : null,
        'knownPeers': status?.listPeers ?? 0,
        'connections': live ? status?.numConnections ?? 0 : 0,
        'candidates': live ? status?.connectCandidates ?? 0 : 0,
        'selectedFile': _selectedFile == null ? null : fileMap(_selectedFile!),
        'downloaded': status?.totalDone ?? 0,
        'selected': _selectedBytes,
        'peers': live ? status?.numPeers ?? 0 : 0,
        'seeds': live ? status?.numSeeds ?? 0 : 0,
        'cached': bytes?.cachedBytes ?? 0,
        'served': _servedBytes,
        'requests': _requests,
      },
    });
  }

  Future<Object?> open(Map source, List peers) async {
    phase = TorrentStreamPhase.acquiringMetadata;
    snapshot();
    await Directory(config.cacheDirectory).create(recursive: true);
    lifetime.check();
    final retained = config.retainedDirectory;
    final root = Directory(config.cacheDirectory);
    if (retained == null) {
      owned = await root.createTemp('torrent-stream-');
    } else {
      saveDirectory = await Directory(
        '${root.path}${Platform.pathSeparator}$retained',
      ).create();
    }
    lifetime.check();
    native = NativeSession(config: config);
    alerts = native!.events.listen(
      (_) {},
      onError: (Object error) {
        lifetime.cancel();
        send({'kind': 'fatal', 'message': 'Native alert pump failed: $error'});
      },
    );
    final save = (owned ?? saveDirectory)!.path;
    torrent = switch (source['kind']) {
      'magnet' => native!.session.addMagnet(
        magnetUri: source['value'] as String,
        savePath: save,
      ),
      'file' => native!.session.addTorrentFile(
        torrentPath: source['value'] as String,
        savePath: save,
      ),
      'bytes' => native!.session.addTorrentData(
        torrentData: source['value'] as Uint8List,
        savePath: save,
      ),
      _ => throw ArgumentError('Unsupported torrent source'),
    };
    torrent!.setFlags(LibtorrentTorrentFlags.defaultDontDownload);
    torrent!.unsetFlags(
      LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
    );
    torrent!.setDownloadLimit(config.downloadBytesPerSecond);
    addPeers(peers);
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      try {
        snapshot();
      } catch (error) {
        lifetime.cancel();
        send({'kind': 'fatal', 'message': 'Native state read failed: $error'});
      }
    });
    await until(() {
      try {
        files = torrent!.getFiles();
        return files.isNotEmpty;
      } catch (_) {
        return false;
      }
    }, 'Torrent metadata');
    torrent!.prioritizeFiles(List.filled(files.length, 0));
    await until(
      () => torrent!.getFilePriorities().every((v) => v == 0),
      'File priorities',
    );
    torrent!.prioritizePieces(List.filled(torrent!.numPieces, 0));
    phase = TorrentStreamPhase.metadataReady;
    snapshot();
    return files.map(fileMap).toList();
  }

  Future<String> prepare(int index) async {
    if (phase != TorrentStreamPhase.metadataReady) {
      throw StateError('Metadata is not ready or a file is already prepared');
    }
    final file = files.firstWhere(
      (f) => f.index == index,
      orElse: () => throw ArgumentError('Unknown file index'),
    );
    if (file.size == 0 || (file.flags & 1) != 0) {
      throw ArgumentError('Select a nonempty, non-pad file');
    }
    _selectedFile = file;
    phase = TorrentStreamPhase.preparing;
    snapshot();
    bytes = TorrentBytes(
      torrent!,
      file,
      (piece, cancel) => native!.read(torrent!, piece, cancel),
      readAheadBytes: config.readAheadBytes,
      maxCacheBytes: config.pieceCacheBytes,
    );
    if (config.prepareContainer) {
      final preparation = bootstrapMedia(bytes!, lifetime, (_) {});
      addPeers(List.of(knownPeers));
      await preparation;
    }
    lifetime.check();
    server = MediaServer(bytes!);
    await server!.start();
    lifetime.check();
    phase = TorrentStreamPhase.serving;
    snapshot();
    return server!.uri.toString();
  }

  Future<void> until(bool Function() ready, String operation) async {
    final watch = Stopwatch()..start();
    while (!ready()) {
      lifetime.check();
      if (watch.elapsed > config.metadataTimeout) {
        throw TimeoutException(operation);
      }
      await lifetime.wait(
        Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    lifetime.check();
  }

  void pause(bool value) {
    if (torrent == null) throw StateError('No torrent open');
    value ? torrent!.pause() : torrent!.resume();
    paused = value;
    snapshot();
  }

  Future<void> close() async {
    if (closed) return;
    closed = true;
    lifetime.cancel();
    timer?.cancel();
    phase = TorrentStreamPhase.closing;
    snapshot();
    await server?.close();
    bytes?.close();
    await alerts?.cancel();
    await native?.close();
    torrent = null;
    native = null;
    bytes = null;
    server = null;
    if (owned != null && await owned!.exists()) {
      await owned!.delete(recursive: true);
    }
    phase = TorrentStreamPhase.closed;
    snapshot();
  }
}
