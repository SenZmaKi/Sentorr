import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

final _punctuation = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
final _whitespace = RegExp(r'\s+');

/// Words that mean the same thing when looking for a setting: a query word
/// that is, or starts, one of them also finds the rest of its line.
const _synonyms = [
  'share seed seeding upload ratio',
  'folder directory location path',
  'speed bandwidth rate throttle',
  'quality resolution 4k 2160p 1080p 720p 480p',
  'clear delete remove erase wipe',
  'cache storage disk space',
  'startup login boot autostart',
  'tray background minimize menubar',
  'theme appearance dark light',
  'notifications alerts notify',
  'languages audio dub dubbed',
  'review confirm countdown autoplay',
  'vpn interface adapter killswitch',
  'reset defaults factory restore',
  'updates upgrade version release',
  'artwork images posters covers backdrops',
  'sources sites providers trackers',
];

final _synonymLines = [for (final line in _synonyms) line.split(' ')];

String _normalize(String value) => value
    .replaceAll(_punctuation, ' ')
    .replaceAll(_whitespace, ' ')
    .trim()
    .toLowerCase();

/// [token] and the synonyms it names, by the whole word or, from three
/// letters, its start.
Set<String> _alternatives(String token) => {
  token,
  for (final line in _synonymLines)
    if (line.any(
      (w) => w == token || (token.length >= 3 && w.startsWith(token)),
    ))
      ...line,
};

/// Optimal string alignment distance: edits, counting a swap of
/// neighbours as one.
int _distance(String a, String b) {
  final d = [
    for (var i = 0; i <= a.length; i++)
      [for (var j = 0; j <= b.length; j++) i == 0 ? j : (j == 0 ? i : 0)],
  ];
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var best = [
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        best = best < d[i - 2][j - 2] + 1 ? best : d[i - 2][j - 2] + 1;
      }
      d[i][j] = best;
    }
  }
  return d[a.length][b.length];
}

/// Whether [token] starts [word], sits inside it, or, when [fuzzy], is a
/// typo or two away from its start.
bool _wordMatches(String token, String word, bool fuzzy) {
  if (word.startsWith(token)) return true;
  if (token.length >= 4 && word.contains(token)) return true;
  if (!fuzzy || token.length < 4) return false;
  final allowed = token.length >= 7 ? 2 : 1;
  // Compare with the start of the word, so a typo in the first letters of
  // a long word still finds it, give or take a letter.
  for (var n = token.length - 1; n <= token.length + 1; n++) {
    if (n > word.length) break;
    if (_distance(token, word.substring(0, n)) <= allowed) return true;
  }
  return false;
}

/// Whether every word of [query] is found in [terms]: starting or inside a
/// word, through a synonym, or across words written together ("autoplay",
/// "autodownload"). [fuzzy] also forgives typos. An empty query matches
/// everything.
bool settingsMatch(
  String? query,
  Iterable<String> terms, {
  bool fuzzy = false,
}) {
  final q = _normalize(query ?? '');
  if (q.isEmpty) return true;
  final text = _normalize(terms.join(' '));
  final words = text.split(' ').toSet();
  final joined = text.replaceAll(' ', '');
  final tokens = q.split(' ');
  if (tokens.length > 1 && joined.contains(tokens.join())) return true;
  return tokens.every(
    (t) =>
        (t.length >= 5 && joined.contains(t)) ||
        _alternatives(t)
            .any((a) => words.any((w) => _wordMatches(a, w, fuzzy))),
  );
}

/// A search typed on the settings page. The page tries it [fuzzy] only
/// when an exact search finds nothing, so typo forgiveness never buries
/// what was asked for under near misses.
@immutable
class SettingsSearch {
  const SettingsSearch(this.text, {this.fuzzy = false});

  final String text;
  final bool fuzzy;

  bool matches(Iterable<String> terms) =>
      settingsMatch(text, terms, fuzzy: fuzzy);
}

/// A setting that can be found by search.
abstract interface class SettingsSearchable {
  bool matches(SettingsSearch? search);
}

/// Collects whether the groups under one search show anything, and tells
/// the page once a frame has settled them.
class SettingsHits {
  SettingsHits(this._onSettled);

  final ValueChanged<bool> _onSettled;
  final _found = <Object, bool>{};
  var _scheduled = false;
  var _closed = false;

  /// Stops reporting, e.g. once a newer search replaces this one.
  void close() => _closed = true;

  void report(Object group, bool found) {
    _found[group] = found;
    if (_scheduled || _closed) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_closed) _onSettled(_found.values.any((f) => f));
    });
  }
}

/// The search in effect below, the category whose settings it shows and
/// where groups say whether they matched. With no search every setting
/// shows; [category] is only set while results from many categories show.
class SettingsQuery extends InheritedWidget {
  const SettingsQuery({
    super.key,
    required this.search,
    required super.child,
    this.hits,
    this.category,
    this.onOpenCategory,
  });

  final SettingsSearch? search;
  final SettingsHits? hits;
  final String? category;

  /// Opens [category] on its own page, leaving the search.
  final VoidCallback? onOpenCategory;

  static SettingsQuery? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsQuery>();

  @override
  bool updateShouldNotify(SettingsQuery old) =>
      search?.text != old.search?.text ||
      search?.fuzzy != old.search?.fuzzy ||
      hits != old.hits ||
      category != old.category;
}
