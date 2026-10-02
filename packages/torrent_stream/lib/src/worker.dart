import 'dart:async';
import 'dart:isolate';

import 'engine/cancellation.dart';
import 'engine/native_host.dart';
import 'models.dart';
import 'wire.dart';

void torrentWorker(SendPort host) {
  final inbox = ReceivePort();
  host.send(inbox.sendPort);
  final clients = <SendPort, _WorkerClient>{};
  inbox.listen((dynamic raw) {
    final message = raw as Map;
    final clientPort = message['host'] as SendPort;
    final client = clients.putIfAbsent(clientPort, _WorkerClient.new);
    final host = clientPort;
    if (message['op'] == 'close') {
      client.stopping = true;
      client.engine?.lifetime.cancel();
    }
    client.queue = client.queue.then((_) async {
      try {
        Object? result;
        if (client.stopping && message['op'] != 'close') {
          throw const ReadCancelled();
        }
        switch (message['op']) {
          case 'open':
            client.engine = NativeHost(
              decodeConfig(message['config'] as Map),
              host.send,
            );
            result = await client.engine!.open(
              message['source'] as Map,
              message['peers'] as List,
            );
          case 'prepare':
            result = await client.engine!.prepare(message['index'] as int);
          case 'peers':
            client.engine!.addPeers(message['peers'] as List);
          case 'seek':
            client.engine?.server?.cancelReads();
          case 'pause':
            client.engine!.pause(message['paused'] as bool);
          case 'close':
            await client.engine?.close();
            clients.remove(clientPort);
          default:
            throw StateError('Unknown operation');
        }
        host.send({'kind': 'reply', 'id': message['id'], 'result': result});
      } catch (error) {
        final code = switch (error) {
          ReadCancelled() => TorrentStreamErrorCode.cancelled,
          TimeoutException() => TorrentStreamErrorCode.timeout,
          ArgumentError() ||
          StateError() => TorrentStreamErrorCode.invalidState,
          _ => TorrentStreamErrorCode.nativeFailure,
        };
        host.send({
          'kind': 'reply',
          'id': message['id'],
          'code': code.index,
          'message': '$error',
        });
      }
    });
  });
}

class _WorkerClient {
  NativeHost? engine;
  bool stopping = false;
  Future<void> queue = Future.value();
}
