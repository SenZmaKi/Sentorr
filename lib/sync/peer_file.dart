import '../player/stream/offline_source.dart';
import '../torrents/resolution_models.dart';
import 'client.dart';
import 'payload.dart';
import 'service.dart';

/// One transport contract for ordinary peer playback and continuity. A partial
/// offer always uses verified bytes on its host, never a receiving torrent.
PeerFile? peerFileForOffer(
  SyncService service,
  String deviceId,
  String name,
  PeerMedia media,
) {
  final buffered = media.bufferedBytes != null;
  final url = service.proxy.url(
    deviceId,
    media.id,
    buffered: buffered,
    infoHash: media.release.infoHash,
    fileVersion: media.version,
  );
  if (url == null) return null;
  return PeerFile(
    url,
    name,
    buffered: buffered,
    torrent: TorrentCandidate(
      release: media.release,
      score: 0,
      qualityScore: 0,
      availabilityScore: 0,
      sizeScore: 0,
      requiresFileSelection: false,
    ),
    fileIndex: media.fileIndex,
    available: () async {
      final route = service.proxy.route(deviceId);
      if (route == null) return false;
      final request = PeerRequest();
      try {
        final response = await request
            .wait(
              service.client.open(
                route.address,
                route.fingerprint,
                '/v1/${buffered ? 'buffered' : 'media'}/${media.id}',
                method: 'HEAD',
                cancellation: request,
                headers: {
                  if (buffered) 'x-sentorr-torrent': media.release.infoHash,
                  if (media.version case final version?)
                    'if-match': '"$version"',
                },
              ),
            )
            .timeout(const Duration(seconds: 3));
        final ready = response.statusCode == 200 || response.statusCode == 206;
        await response.drain<void>();
        request.complete();
        return ready;
      } on Object {
        return false;
      } finally {
        request.cancel();
      }
    },
  );
}
