import 'package:test/test.dart';
import 'package:torrent_stream/src/stream_state.dart';
import 'package:torrent_stream/torrent_stream.dart';

void main() {
  test(
    'stream telemetry distinguishes traffic, availability and peer counts',
    () {
      const film = TorrentStreamFile(
        index: 2,
        path: 'film.mkv',
        length: 1000,
        isPadFile: false,
      );
      final state = streamStateOf(
        const TorrentSnapshot(
          infoHash: 'ab',
          savePath: '/tmp',
          storage: TorrentStorage.temporary,
          fileBytes: [0, 0, 500],
          downloadBytesPerSecond: 4000000,
          uploadBytesPerSecond: 125000,
          receivedBytes: 1200,
          uploadedBytes: 300,
          transferState: TorrentTransferState.downloading,
          knownPeers: 20,
          connections: 7,
          connectionCandidates: 12,
          verifiedBytes: 900,
          peers: 5,
          seeds: 2,
          streams: [
            StreamSnapshot(
              id: 4,
              owner: 'stream:1',
              file: film,
              cachedBytes: 100,
              servedBytes: 200,
              requests: 3,
            ),
          ],
        ),
        phase: TorrentStreamPhase.serving,
        transferPaused: false,
        selectedFile: film,
        stream: 4,
      );
      expect(state.uploadBytesPerSecond, 125000);
      expect(state.uploadedBytes, 300);
      expect(state.receivedBytes, greaterThan(state.verifiedBytes));
      expect(state.selectedProgress, 0.5);
      expect(state.connectedPeers, 5);
      expect(state.connectedSeeds, 2);
      expect(state.knownPeers, 20);
      expect(state.connections, 7);
      expect(state.connectionCandidates, 12);
      expect(state.servedBytes, 200);
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
