import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/player/torrent_lookup.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';

import 'fake_torrents.dart';

/// A candidate for [release], scored as found.
TorrentCandidate fakeCandidate(TorrentRelease release) => TorrentCandidate(
  release: release,
  score: 1,
  qualityScore: 1,
  availabilityScore: 1,
  sizeScore: 1,
  requiresFileSelection: release.isPack,
);

/// Answers torrent searches from [found] by item id, else [fallback];
/// records each item searched. [gate] holds every search until completed.
class FakeSearch {
  FakeSearch({this.found = const {}, this.fallback});

  Map<String, List<TorrentRelease>> found;
  List<TorrentRelease>? fallback;
  Completer<void>? gate;
  final searched = <String>[];

  Future<TorrentResolution> call(
    PlaybackItem item, {
    String? title,
    CancelToken? cancel,
  }) async {
    searched.add(item.id);
    await gate?.future;
    if (cancel?.isCancelled ?? false) throw cancel!.cancelError!;
    final releases = found[item.id] ?? fallback ?? [fakeRelease(1)];
    return TorrentResolution(
      query: torrentQueryFor(item, title: title),
      candidates: [for (final r in releases) fakeCandidate(r)],
      failures: const [],
    );
  }
}
