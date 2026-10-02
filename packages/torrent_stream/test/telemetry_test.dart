import 'package:test/test.dart';
import 'package:torrent_stream/src/wire.dart';
import 'package:torrent_stream/torrent_stream.dart';

void main() {
  test(
    'worker telemetry distinguishes traffic, availability and peer counts',
    () {
      final state = decodeState({
        'phase': TorrentStreamPhase.serving.index,
        'files': [],
        'paused': false,
        'rate': 4000000,
        'uploadRate': 125000,
        'received': 1200,
        'uploaded': 300,
        'torrentState': 3,
        'knownPeers': 20,
        'connections': 7,
        'candidates': 12,
        'selectedFile': {
          'index': 2,
          'path': 'film.mkv',
          'length': 1000,
          'pad': false,
        },
        'downloaded': 900,
        'selected': 500,
        'peers': 5,
        'seeds': 2,
        'cached': 100,
        'served': 200,
        'requests': 3,
      });
      expect(state.uploadBytesPerSecond, 125000);
      expect(state.uploadedBytes, 300);
      expect(state.receivedBytes, greaterThan(state.verifiedBytes));
      expect(state.selectedProgress, 0.5);
      expect(state.connectedPeers, 5);
      expect(state.connectedSeeds, 2);
      expect(state.knownPeers, 20);
      expect(state.connections, 7);
      expect(state.connectionCandidates, 12);
      expect(state.transferState, TorrentTransferState.downloading);
      final closed = state.atPhase(TorrentStreamPhase.closed);
      expect(closed.uploadedBytes, 300);
      expect(closed.receivedBytes, 1200);
      expect(closed.selectedProgress, 0.5);
      expect(closed.uploadBytesPerSecond, 0);
      expect(closed.connectedPeers, 0);
      expect(closed.servedBytes, 200);
    },
  );
}
