import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sentorr/library/models.dart';
import 'package:sentorr/library/planner.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';
import 'package:sentorr/player/stream/reusable_torrent.dart';
import 'package:torrent_stream/torrent_stream.dart';

/// Records what it was asked to download; [missing] ids have no exact
/// match.
class FakePlanner implements DownloadPlanner {
  Completer<void>? gate;
  final planned = <String>[];
  final origins = <LibraryOrigin>[];
  Set<String> missing = {};

  /// Torrents each download was given, null when it searched.
  final given = <TorrentCandidate?>[];

  /// What a search finds; [missing] ids are not in it.
  TorrentCandidate? found;

  @override
  Future<void> downloadStream(
    PlaybackItem item,
    ReusableTorrent torrent, {
    Uint8List? metadata,
    required String directory,
    required TorrentStorage storage,
  }) async {
    planned.add(item.id);
  }

  @override
  Future<TorrentCandidate?> download(
    PlaybackItem item, {
    TorrentCandidate? torrent,
    LibraryOrigin origin = LibraryOrigin.manual,
    String? reason,
    CancelToken? cancel,
  }) async {
    await gate?.future;
    if (cancel?.isCancelled ?? false) throw cancel!.cancelError!;
    origins.add(origin);
    given.add(torrent);
    if (missing.contains(item.id)) {
      throw const DownloadPlanException('No exact torrent match to download.');
    }
    planned.add(item.id);
    return torrent ?? found;
  }
}
