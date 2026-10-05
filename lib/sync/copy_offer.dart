import '../player/models.dart';
import 'payload.dart';

/// A finished file on a paired device that can be copied here instead of
/// downloaded.
typedef PeerCopy = ({String deviceId, String deviceName, PeerMedia media});

/// What reachable paired devices can supply of a download, and how to say
/// so.
class CopyOffer {
  const CopyOffer(this.copies);

  /// Wanted items found on reachable devices, the first device holding each,
  /// in air order.
  ///
  /// [devices] are each reachable device's id, name and shared media, in
  /// the order to prefer them; [wanted] says whether an item is asked for
  /// and not already here.
  factory CopyOffer.find(
    Iterable<({String id, String name, List<PeerMedia> media})> devices,
    bool Function(PlaybackItem item) wanted,
  ) {
    final found = <String, PeerCopy>{};
    for (final d in devices) {
      for (final m in d.media) {
        if (found.containsKey(m.id) || !wanted(m.item)) continue;
        found[m.id] = (deviceId: d.id, deviceName: d.name, media: m);
      }
    }
    return CopyOffer([...found.values]..sort(_airOrder));
  }

  final List<PeerCopy> copies;

  bool get isEmpty => copies.isEmpty;
  Set<String> get ids => {for (final c in copies) c.media.id};

  /// "MacBook", "MacBook and iPad", "MacBook, iPad and Pixel".
  String get devices => _list({for (final c in copies) c.deviceName}.toList());

  /// What is on offer, e.g. "episodes 1–3 and 5" of one season, or the
  /// movie's title.
  String get what {
    final items = [for (final c in copies) c.media.item];
    final seasons = {for (final i in items) (i.series?.id, i.season)};
    if (items.any((i) => i.series == null || i.episode == null) ||
        seasons.length > 1) {
      return _list([for (final i in items) _label(i)]);
    }
    final numbers = [for (final i in items) i.episode!];
    return '${numbers.length == 1 ? 'episode' : 'episodes'} '
        '${_list(_runs(numbers))}';
  }

  /// "episodes 1–3 and 5 are on MacBook", or with several devices, which
  /// device has which.
  String get summary {
    final byDevice = <String, List<PeerCopy>>{};
    for (final c in copies) {
      (byDevice[c.deviceName] ??= []).add(c);
    }
    return _list([
      for (final MapEntry(key: name, value: some) in byDevice.entries)
        '${CopyOffer(some).what} on $name',
    ]);
  }
}

/// "1–3", "5", "7–8" for consecutive numbers.
List<String> _runs(List<int> numbers) {
  final sorted = {...numbers}.toList()..sort();
  final runs = <String>[];
  for (var i = 0; i < sorted.length;) {
    var j = i;
    while (j + 1 < sorted.length && sorted[j + 1] == sorted[j] + 1) {
      j++;
    }
    runs.add(j == i ? '${sorted[i]}' : '${sorted[i]}–${sorted[j]}');
    i = j + 1;
  }
  return runs;
}

String _list(List<String> parts) => switch (parts.length) {
  0 => '',
  1 => parts.single,
  _ => '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}',
};

String _label(PlaybackItem item) => item.series == null
    ? item.name
    : '${item.series!.title} S${item.season} E${item.episode}';

int _airOrder(PeerCopy a, PeerCopy b) {
  final x = a.media.item, y = b.media.item;
  final season = (x.season ?? 0).compareTo(y.season ?? 0);
  return season != 0 ? season : (x.episode ?? 0).compareTo(y.episode ?? 0);
}
