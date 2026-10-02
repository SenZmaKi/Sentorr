import 'dart:io';
import 'dart:typed_data';

/// A resolved source, without catalog/search assumptions. Metadata bytes are
/// copied immediately so later caller mutations cannot change the torrent.
sealed class TorrentSource {
  const TorrentSource();
  factory TorrentSource.magnet(Uri uri) => MagnetSource(uri);
  factory TorrentSource.file(String path) => TorrentFileSource(path);
  factory TorrentSource.metadata(Uint8List bytes) =>
      TorrentMetadataSource(bytes);
}

final class MagnetSource extends TorrentSource {
  MagnetSource(this.uri) {
    if (uri.scheme != 'magnet' || !uri.queryParametersAll.containsKey('xt')) {
      throw ArgumentError.value(
        uri,
        'uri',
        'Expected a magnet with an exact topic',
      );
    }
  }
  final Uri uri;
}

final class TorrentFileSource extends TorrentSource {
  TorrentFileSource(this.path) {
    if (!File(path).isAbsolute) {
      throw ArgumentError('Torrent path must be absolute');
    }
  }
  final String path;
}

final class TorrentMetadataSource extends TorrentSource {
  TorrentMetadataSource(Uint8List bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    if (bytes.isEmpty) throw ArgumentError('Torrent metadata cannot be empty');
  }
  final Uint8List bytes;
}

/// Optional known peers, useful for explicit discovery or local/offline seeds.
class TorrentPeer {
  TorrentPeer(this.address, this.port) {
    if (InternetAddress.tryParse(address) == null || port < 1 || port > 65535) {
      throw ArgumentError('A peer requires an IP address and valid port');
    }
  }
  final String address;
  final int port;
}
