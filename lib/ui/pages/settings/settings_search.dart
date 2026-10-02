import 'package:flutter/widgets.dart';

final _punctuation = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
final _whitespace = RegExp(r'\s+');

/// Words people use when looking for a setting rather than its label.
const _aliases = <String, String>{
  'launch at startup': 'login boot autostart auto start',
  'always on top': 'pin window floating',
  'close to tray': 'minimize tray menu bar background hide',
  'preferred quality': 'resolution 4k 2160p 1080p 720p 480p video',
  'audio languages': 'dub language audio track',
  'show the torrent': 'review confirm countdown autoplay skip wait delay',
  'download limit': 'speed bandwidth rate',
  'torrent folder': 'download location directory path save',
  'keep recent torrents': 'lru cache reuse delete remove',
  'image cache': 'artwork posters covers',
  'reset settings': 'factory defaults restore',
};

String _normalize(String value) => value
    .replaceAll(_punctuation, ' ')
    .replaceAll(_whitespace, ' ')
    .trim()
    .toLowerCase();

/// Whether every word of [query] starts a word of [terms] or their
/// aliases. An empty query matches everything.
bool settingsMatch(String? query, Iterable<String> terms) {
  final q = _normalize(query ?? '');
  if (q.isEmpty) return true;
  final text = _normalize(terms.join(' '));
  final words = {
    ...text.split(' '),
    for (final MapEntry(:key, :value) in _aliases.entries)
      if (text.contains(key)) ...value.split(' '),
  };
  return q.split(' ').every((t) => words.any((w) => w.startsWith(t)));
}

/// A setting that can be found by search.
abstract interface class SettingsSearchable {
  bool matches(String? query);
}

/// The search in effect below; null shows every setting.
class SettingsQuery extends InheritedWidget {
  const SettingsQuery({super.key, required this.query, required super.child});

  final String? query;

  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsQuery>()?.query;

  @override
  bool updateShouldNotify(SettingsQuery old) => query != old.query;
}
