import '../imdb/models.dart';
import '../player/models.dart';
import '../torrents/match.dart';
import '../torrents/resolution_models.dart';

/// Where one item of a download review stands.
enum ReviewStatus {
  /// Not searched yet; earlier items go first.
  waiting,
  searching,

  /// Matches the preferences, or shares a season pack found earlier.
  ready,

  /// The best torrent compromises on the preferences; it downloads unless
  /// another is chosen.
  close,

  /// Nothing was found; it must be chosen or skipped.
  missing,

  /// The viewer picked the torrent.
  chosen,
  skipped,
}

/// One movie or episode in a download review: its search and the torrent
/// it will download from.
class ReviewEntry {
  const ReviewEntry(
    this.item, {
    this.resolution,
    this.match,
    this.torrent,
    this.title,
    this.fromPack = false,
    this.chosen = false,
    this.skipped = false,
    this.searching = false,
    this.error,
  });

  final PlaybackItem item;

  /// Its own search; null until searched, or when it shares a pack.
  final TorrentResolution? resolution;
  final TorrentMatch? match;

  /// What it downloads from; null on a miss.
  final TorrentCandidate? torrent;

  /// The title searched under, when the viewer typed another.
  final String? title;

  /// Shares the season pack found for an earlier episode, unsearched.
  final bool fromPack;
  final bool chosen, skipped, searching;

  /// The search failed outright, e.g. no network.
  final Object? error;

  ReviewStatus get status {
    if (skipped) return ReviewStatus.skipped;
    if (searching) return ReviewStatus.searching;
    if (chosen) return ReviewStatus.chosen;
    if (torrent == null) {
      return resolution == null && error == null
          ? ReviewStatus.waiting
          : ReviewStatus.missing;
    }
    if (fromPack) return ReviewStatus.ready;
    return concerns.isEmpty ? ReviewStatus.ready : ReviewStatus.close;
  }

  /// What the best torrent compromises on. Packs are no compromise for a
  /// download: only the item's file is kept, checked once metadata arrives.
  List<MatchConcern> get concerns => [
    for (final c in match?.concerns ?? const <MatchConcern>[])
      if (c != MatchConcern.seasonPack && c != MatchConcern.seriesPack) c,
  ];

  bool get settled =>
      status != ReviewStatus.waiting && status != ReviewStatus.searching;

  /// Waits on the viewer before the review can download.
  bool get blocking => status == ReviewStatus.missing;

  /// Flagged for the viewer: a compromise or a miss.
  bool get needsChoice =>
      status == ReviewStatus.close || status == ReviewStatus.missing;

  /// Downloads when the review is confirmed.
  bool get downloads => !skipped && torrent != null;

  ReviewEntry searched(TorrentResolution resolution, TorrentMatch? match) =>
      ReviewEntry(
        item,
        resolution: resolution,
        match: match,
        torrent: match?.candidate,
        title: title,
      );

  ReviewEntry failed(Object error) =>
      ReviewEntry(item, title: title, error: error);

  ReviewEntry startSearch({String? title}) => ReviewEntry(
    item,
    resolution: resolution,
    match: match,
    torrent: torrent,
    title: title ?? this.title,
    fromPack: fromPack,
    chosen: chosen,
    searching: true,
  );

  ReviewEntry sharing(TorrentCandidate pack) =>
      ReviewEntry(item, torrent: pack, fromPack: true, title: title);

  ReviewEntry choose(TorrentCandidate candidate) => ReviewEntry(
    item,
    resolution: resolution,
    match: match,
    torrent: candidate,
    title: title,
    chosen: true,
  );

  ReviewEntry skip(bool skipped) => ReviewEntry(
    item,
    resolution: resolution,
    match: match,
    torrent: torrent,
    title: title,
    fromPack: fromPack,
    chosen: chosen,
    skipped: skipped,
    searching: searching,
    error: error,
  );
}

/// Movies or episodes whose torrents are being found, then shown to the
/// viewer before they download: one item, or a season.
class DownloadReview {
  const DownloadReview({
    required this.id,
    this.entries = const [],
    this.series,
    this.season,
    this.listing = false,
    this.shown = false,
    this.error,
  });

  final int id;
  final List<ReviewEntry> entries;

  /// Set when the review is a season.
  final ImdbTitle? series;
  final int? season;

  /// A season's aired episodes are still being listed.
  final bool listing;

  /// Showing to the viewer: always when they review downloads, or asked
  /// to; otherwise once the search needs them.
  final bool shown;

  /// The season's episodes could not be listed.
  final Object? error;

  bool get isSeason => season != null;
  bool get searching => listing || entries.any((e) => !e.settled);
  int get settledCount => entries.where((e) => e.settled).length;
  bool get blocked => entries.any((e) => e.blocking);
  bool get needsChoice => entries.any((e) => e.needsChoice);
  List<ReviewEntry> get downloading => [
    for (final e in entries)
      if (e.downloads) e,
  ];

  /// Every item found as asked: it may download without the viewer.
  bool get exact =>
      !searching &&
      error == null &&
      downloading.isNotEmpty &&
      !blocked &&
      !needsChoice;

  /// The torrents' size; a shared pack counts its episodes' share once.
  int get bytes {
    var total = 0;
    final packs = <String>{};
    for (final e in downloading) {
      final r = e.torrent!.release;
      if (r.isPack && !packs.add(r.infoHash)) continue;
      total += r.sizeBytes;
    }
    return total;
  }

  DownloadReview copyWith({
    List<ReviewEntry>? entries,
    bool? listing,
    bool? shown,
    Object? error,
  }) => DownloadReview(
    id: id,
    entries: entries ?? this.entries,
    series: series,
    season: season,
    listing: listing ?? this.listing,
    shown: shown ?? this.shown,
    error: error ?? this.error,
  );

  DownloadReview replacing(
    String itemId,
    ReviewEntry Function(ReviewEntry) f,
  ) => copyWith(
    entries: [for (final e in entries) e.item.id == itemId ? f(e) : e],
  );

  ReviewEntry? entry(String itemId) =>
      entries.where((e) => e.item.id == itemId).firstOrNull;
}
