import 'dart:async';
import 'dart:isolate';

import 'config.dart';
import 'engine/cancellation.dart';
import 'engine/core.dart';
import 'engine_models.dart';
import 'models.dart';

/// Hosts one [EngineCore] per client engine. Commands run concurrently: a
/// stream waiting on pieces must not hold up another torrent's pause.
void torrentWorker(SendPort host) {
  final inbox = ReceivePort();
  host.send(inbox.sendPort);
  final cores = <SendPort, EngineCore>{};
  inbox.listen((dynamic raw) {
    final message = raw as Map;
    final client = message['host'] as SendPort;
    unawaited(() async {
      try {
        final result = await _run(cores, client, message);
        client.send({'kind': 'reply', 'id': message['id'], 'result': result});
      } catch (error) {
        final code = switch (error) {
          ReadCancelled() => TorrentStreamErrorCode.cancelled,
          TimeoutException() => TorrentStreamErrorCode.timeout,
          ArgumentError() ||
          StateError() => TorrentStreamErrorCode.invalidState,
          _ => TorrentStreamErrorCode.nativeFailure,
        };
        client.send({
          'kind': 'reply',
          'id': message['id'],
          'code': code.index,
          'message': '$error',
        });
      }
    }());
  });
}

Future<Object?> _run(
  Map<SendPort, EngineCore> cores,
  SendPort client,
  Map message,
) async {
  final op = message['op'] as String;
  if (op == 'start') {
    final settings = message['settings'] as TorrentEngineSettings;
    final known = cores[client];
    if (known != null) {
      known.configure(settings);
    } else {
      cores[client] = EngineCore(settings, client.send);
    }
    return null;
  }
  final core = cores[client] ?? (throw StateError('Engine not started'));
  String hash() => message['hash'] as String;
  String owner() => message['owner'] as String;
  switch (op) {
    case 'configure':
      core.configure(message['settings'] as TorrentEngineSettings);
    case 'add':
      return core.add(
        message['source'] as Map,
        owner: owner(),
        directory: message['directory'] as String,
        storage: message['storage'] as TorrentStorage,
        peers: message['peers'] as List,
      );
    case 'metadata':
      return core.metadata(hash(), message['timeout'] as Duration?);
    case 'want':
      await core.want(hash(), owner(), (message['files'] as Set).cast<int>());
    case 'pause':
      await core.pause(hash(), owner(), message['paused'] as bool);
    case 'rename':
      await core.rename(hash(), (message['names'] as Map).cast<int, String>());
    case 'move':
      await core.move(
        hash(),
        message['directory'] as String,
        message['storage'] as TorrentStorage,
      );
    case 'peers':
      core.addPeers(hash(), message['peers'] as List);
    case 'stream':
      return core.stream(
        hash(),
        owner(),
        message['index'] as int,
        message['options'] as StreamOptions,
      );
    case 'prefetch':
      core.prefetch(
        message['stream'] as int,
        message['start'] as int,
        message['end'] as int,
      );
    case 'seek':
      core.seek(message['stream'] as int);
    case 'closeStream':
      await core.closeStream(message['stream'] as int);
    case 'release':
      await core.release(
        hash(),
        owner(),
        deleteFiles: message['delete'] as bool,
      );
    case 'close':
      cores.remove(client);
      await core.close();
    default:
      throw StateError('Unknown operation');
  }
  return null;
}
