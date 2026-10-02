import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';

/// Records what it was asked to download; [missing] ids have no exact
/// match.
class FakePlanner implements DownloadPlanner {
  Completer<void>? gate;
  final planned = <String>[];
  final automatic = <bool>[];
  Set<String> missing = {};

  /// Torrents each download was given, null when it searched.
  final given = <TorrentCandidate?>[];

  /// What a search finds; [missing] ids are not in it.
  TorrentCandidate? found;

  @override
  Future<TorrentCandidate?> download(
    PlaybackItem item, {
    TorrentCandidate? torrent,
    bool automatic = false,
    CancelToken? cancel,
  }) async {
    await gate?.future;
    if (cancel?.isCancelled ?? false) throw cancel!.cancelError!;
    this.automatic.add(automatic);
    given.add(torrent);
    if (missing.contains(item.id)) {
      throw const DownloadPlanException('No exact torrent match to download.');
    }
    planned.add(item.id);
    return torrent ?? found;
  }
}
