import 'package:sentorr/library/planner.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';

/// Records what it was asked to download; [missing] ids have no exact
/// match.
class FakePlanner implements DownloadPlanner {
  final planned = <String>[];
  final automatic = <bool>[];
  Set<String> missing = {};

  @override
  Future<void> download(
    PlaybackItem item, {
    TorrentCandidate? torrent,
    bool automatic = false,
  }) async {
    this.automatic.add(automatic);
    if (missing.contains(item.id)) {
      throw const DownloadPlanException('No exact torrent match to download.');
    }
    planned.add(item.id);
  }
}
