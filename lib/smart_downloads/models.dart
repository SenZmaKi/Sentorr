import '../player/models.dart';

/// What smart downloads are doing, for the Downloads page.
enum SmartStatus {
  off,

  /// Nothing watched yet to pick from.
  noHistory,

  /// Choosing and queuing picks.
  filling,

  /// Picks are queued and downloading.
  downloading,

  /// The reserve holds the target.
  full,
  waitingForPlayback,

  /// The viewer's own downloads go first.
  waitingForDownloads,
  offline,
  waitingForWifi,

  /// Downloads fill their space and nothing watched can make room.
  overBudget,

  /// Everything worth picking is downloaded or has no matching torrent.
  nothingToPick,
}

/// A movie or episode smart downloads would download, and why.
class SmartPick {
  const SmartPick(this.item, this.reason);
  final PlaybackItem item;

  /// In the viewer's terms, e.g. `Next episode`.
  final String reason;

  @override
  String toString() => '$item: $reason';
}
