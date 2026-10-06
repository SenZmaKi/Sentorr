import 'package:torrent_stream/torrent_stream.dart';

import '../../torrents/resolution_models.dart';
import '../models.dart';

/// What the viewer has of an item offline, so playback skips the search.
sealed class OfflineSource {
  const OfflineSource();
}

/// The finished file on disk.
class LocalFile extends OfflineSource {
  const LocalFile(this.path, {this.transfers});
  final String path;

  /// The existing download keeps sharing while the player reads from disk.
  final Stream<TorrentStreamState>? transfers;
}

/// A download in progress: stream its torrent's file, sharing the transfer.
class DownloadTorrent extends OfflineSource {
  const DownloadTorrent(this.torrent, this.fileIndex);
  final TorrentCandidate torrent;
  final int fileIndex;
}

/// A finished download on a paired device, served over the local network.
class PeerFile extends OfflineSource {
  const PeerFile(this.url, this.deviceName);

  /// Loopback; the proxy behind it reaches the device.
  final Uri url;
  final String deviceName;
}

typedef OfflineLookup = OfflineSource? Function(PlaybackItem item);
