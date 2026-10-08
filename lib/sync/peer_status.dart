import 'payload.dart';

/// How a paired device looks from here.
class PeerStatus {
  const PeerStatus({
    this.online = false,
    this.syncing = false,
    this.incompatible = false,
    this.error,
    this.libraryRevision,
    this.media = const [],
    this.downloads = const [],
  });

  /// Answered its last request.
  final String? libraryRevision;
  final bool online;
  final bool syncing;

  /// Reachable, but its declared formats cannot be exchanged safely.
  final bool incompatible;

  /// Why it was last unreachable.
  final String? error;

  /// Its finished downloads this device can stream or copy.
  final List<PeerMedia> media;

  /// Its downloads still on their way.
  final List<PeerDownload> downloads;

  PeerStatus copyWith({
    bool? online,
    bool? syncing,
    bool? incompatible,
    String? Function()? error,
    PeerLibrary? library,
  }) => PeerStatus(
    online: online ?? this.online,
    syncing: syncing ?? this.syncing,
    incompatible: incompatible ?? this.incompatible,
    error: error == null ? this.error : error(),
    libraryRevision: library == null ? libraryRevision : library.revision,
    media: library?.media ?? media,
    downloads: library?.downloads ?? downloads,
  );
}
