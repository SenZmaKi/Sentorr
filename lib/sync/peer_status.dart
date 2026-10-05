import 'payload.dart';

/// How a paired device looks from here.
class PeerStatus {
  const PeerStatus({
    this.online = false,
    this.syncing = false,
    this.error,
    this.media = const [],
    this.downloads = const [],
  });

  /// Answered its last request.
  final bool online;
  final bool syncing;

  /// Why it was last unreachable.
  final String? error;

  /// Its finished downloads this device can stream or copy.
  final List<PeerMedia> media;

  /// Its downloads still on their way.
  final List<PeerDownload> downloads;

  PeerStatus copyWith({
    bool? online,
    bool? syncing,
    String? Function()? error,
    PeerLibrary? library,
  }) => PeerStatus(
    online: online ?? this.online,
    syncing: syncing ?? this.syncing,
    error: error == null ? this.error : error(),
    media: library?.media ?? media,
    downloads: library?.downloads ?? downloads,
  );
}
