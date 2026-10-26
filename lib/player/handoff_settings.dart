import '../settings/playback_preferences.dart';

/// Playback intent for this viewing session, independent of device paths,
/// torrent/cache settings and other titles' saved preferences.
class HandoffSettings {
  const HandoffSettings({
    required this.volume,
    required this.speed,
    required this.item,
  });
  final double volume, speed;
  final ItemPlaybackPreferences item;

  PlaybackPreferences applyTo(PlaybackPreferences local, String itemId) => local
      .copyWith(volume: volume, speed: speed)
      .updateItem(itemId, (_) => item);

  Map<String, dynamic> toJson() => {
    'volume': volume,
    'speed': speed,
    'item': item.toJson(),
  };

  static HandoffSettings? decode(Object? value) {
    if (value == null) return null; // Version-1 peers can omit playback intent.
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid playback settings');
    }
    final volume = value['volume'], speed = value['speed'];
    if (volume is! num ||
        !volume.isFinite ||
        volume < 0 ||
        volume > 100 ||
        speed is! num ||
        !speed.isFinite ||
        speed < 0.25 ||
        speed > 2 ||
        value['item'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid playback settings');
    }
    try {
      return HandoffSettings(
        volume: volume.toDouble(),
        speed: speed.toDouble(),
        item: ItemPlaybackPreferences.fromJson(
          value['item'] as Map<String, dynamic>,
        ),
      );
    } catch (_) {
      throw const FormatException('Invalid playback track settings');
    }
  }
}
