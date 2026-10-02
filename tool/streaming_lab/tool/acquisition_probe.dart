import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:streaming_lab/engine/lab_session.dart';
import 'package:streaming_lab/engine/cancellation.dart';

Future<void> main() async {
  final lab = LabSession((_) {});
  final cancel = Cancellation();
  var done = false;
  try {
    final files = await lab.open(
      'fixtures/network-tail.mp4',
      controlled: true,
      downloadMbps: 10,
    );
    await lab.select(files.first['index'] as int);
    unawaited(
      lab.bytes!
          .read(0, 65536, cancel)
          .then(
            (_) => done = true,
            onError: (Object e) {
              stdout.writeln(e);
              done = true;
            },
          ),
    );
    for (var second = 0; second < 25 && !done; second++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final t = lab.torrent!, status = t.getStatus();
      stdout.writeln(
        jsonEncode({
          'second': second,
          'done': done,
          'bytes': status.totalDone,
          'state': status.state,
          'priority': t.getPiecePriority(0),
          'queue': t
              .getDownloadQueue()
              .map(
                (p) => {
                  'piece': p.pieceIndex,
                  'blocks': p.blocksInPiece,
                  'finished': p.finished,
                  'writing': p.writing,
                  'requested': p.requested,
                },
              )
              .toList(),
          'peer': t
              .getPeerInfo()
              .map((p) => {'flags': p.flags, 'download': p.payloadDownSpeed})
              .toList(),
          'seedPeer': lab.seed!
              .getPeerInfo()
              .map((p) => {'flags': p.flags, 'upload': p.payloadUpSpeed})
              .toList(),
        }),
      );
    }
  } finally {
    cancel.cancel();
    await lab.close();
  }
}
