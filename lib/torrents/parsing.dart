import 'models.dart';

int? integer(Object? value) => int.tryParse('$value');
String? infoHash(Object? value) {
  final text = '$value';
  if (!RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(text) ||
      RegExp(r'^0+$').hasMatch(text)) {
    return null;
  }
  return text.toLowerCase();
}

Uri magnetFor(String hash, String name) => Uri(
  scheme: 'magnet',
  queryParameters: {'xt': 'urn:btih:$hash', 'dn': name},
);
String? magnetHash(Uri? uri) {
  if (uri?.scheme != 'magnet') return null;
  for (final xt in uri!.queryParametersAll['xt'] ?? <String>[]) {
    if (xt.toLowerCase().startsWith('urn:btih:')) {
      return infoHash(xt.substring(9));
    }
  }
  return null;
}

int? parseSize(String text) {
  final m = RegExp(
    r'^([0-9]+(?:\.[0-9]+)?)\s*(B|[KMGT]i?B)$',
    caseSensitive: false,
  ).firstMatch(text.trim());
  if (m == null) return null;
  final unit = m[2]!.toUpperCase().replaceAll('I', '');
  final power = ['B', 'KB', 'MB', 'GB', 'TB'].indexOf(unit);
  var bytes = double.parse(m[1]!);
  for (var i = 0; i < power; i++) {
    bytes *= 1024;
  }
  return bytes.isFinite ? bytes.round() : null;
}

int? resolutionOf(String text) {
  final m = RegExp(
    r'(?:^|[^\d])(2160|1080|720|576|540|480)p\b',
    caseSensitive: false,
  ).firstMatch(text.replaceAll('.', ' '));
  if (m != null) return int.parse(m[1]!);
  return RegExp(r'\b(?:4k|uhd)\b', caseSensitive: false).hasMatch(text)
      ? 2160
      : null;
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

/// Conservative full-title comparison, without token-subset matching.
double titleSimilarity(String left, String right) {
  final a = _normalize(left), b = _normalize(right);
  if (a.isEmpty || b.isEmpty) return 0;
  var row = List.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final next = <int>[i + 1];
    for (var j = 0; j < b.length; j++) {
      final values = [
        next[j] + 1,
        row[j + 1] + 1,
        row[j] + (a[i] == b[j] ? 0 : 1),
      ];
      next.add(values.reduce((a, b) => a < b ? a : b));
    }
    row = next;
  }
  final length = a.length > b.length ? a.length : b.length;
  return 1 - row.last / length;
}

final _season = RegExp(
  r'\b(?:s(\d{1,2})|season\s*(\d{1,2}))(?:\s*(?:e|episode\s*)(\d{1,3})(?!\d))?\b',
  caseSensitive: false,
);
final _marker = RegExp(
  r'\b(?:s\d{1,2}(?:e\d{1,3})?|season\s*\d{1,2}|(?:19|20)\d{2}|2160p|1080p|720p|480p|4k|uhd|bluray|brrip|bdrip|webrip|web-dl|hdtv|x264|x265)\b',
  caseSensitive: false,
);

bool matchesRelease(
  TorrentQuery query,
  String name, {
  bool trustedIdentity = false,
}) {
  final clean = name
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .replaceAll(RegExp(r'[._]'), ' ')
      .trim();
  final seasons = _season.allMatches(clean).toList();
  if (query.isSeries) {
    // Multi-season/range/multi-episode releases need a richer parser; fail closed.
    if (seasons.length != 1 ||
        RegExp(
          r'\b(?:s\d+|e\d+)\s*[-–]\s*(?:s|e)?\d+|e\d+e\d+',
          caseSensitive: false,
        ).hasMatch(clean)) {
      return false;
    }
    final s = seasons.single;
    if (int.parse(s[1] ?? s[2]!) != query.season) return false;
    final episode = integer(s[3]);
    if (query.isSeasonPack ? episode != null : episode != query.episode) {
      return false;
    }
  } else if (seasons.isNotEmpty) {
    return false;
  }
  if (!query.isSeries &&
      RegExp(
            r'\b(?:collection|trilogy|quadrilogy|anthology|pack)\b|\b\d+\s*[-–]\s*\d+\b',
            caseSensitive: false,
          )
          .allMatches(clean)
          .any(
            (m) => !query.title.toLowerCase().contains(m[0]!.toLowerCase()),
          )) {
    return false;
  }
  final years = RegExp(r'\b((?:19|20)\d{2})\b')
      .allMatches(clean)
      .where(
        (m) =>
            !_normalize(query.title)
                .startsWith(_normalize(clean.substring(0, m.end))),
      );
  final year = years.isEmpty ? null : years.first;
  if (query.year != null && year != null && integer(year[1]) != query.year) {
    return false;
  }
  if (!trustedIdentity) {
    final markers = _marker
        .allMatches(clean)
        .where(
          (m) =>
              !_normalize(query.title)
                  .startsWith(_normalize(clean.substring(0, m.end))),
        );
    final marker = markers.isEmpty ? null : markers.first;
    final title =
        (marker == null
                ? clean.replaceFirst(
                    RegExp(r'\s+(mkv|mp4|avi)$', caseSensitive: false),
                    '',
                  )
                : clean.substring(0, marker.start))
            .replaceAll(RegExp(r'\[[^\]]*\]'), '')
            .trim();
    // Short and numeric titles require exact comparison; fuzzy matching admits sequels.
    final digits = RegExp(r'\d+');
    if (digits.allMatches(title).map((m) => m[0]).join(',') !=
        digits.allMatches(query.title).map((m) => m[0]).join(',')) {
      return false;
    }
    final exact = _normalize(title) == _normalize(query.title);
    if (!exact &&
        (RegExp(r'\d').hasMatch(query.title) ||
            _normalize(query.title).length < 8 ||
            titleSimilarity(query.title, title) < .88)) {
      return false;
    }
  }
  if (query.languages.isNotEmpty) {
    final lower = clean.toLowerCase();
    if (!query.languages.any(
      (language) => RegExp(
        '\\b(?:${languageTokens(language).map(RegExp.escape).join('|')})\\b',
      ).hasMatch(lower),
    )) {
      return false;
    }
  }
  return true;
}

DateTime? unixDate(Object? value) {
  final seconds = integer(value);
  if (seconds == null || seconds < 0 || seconds > 253402300799) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

String normalizeLanguage(String language) => switch (language.toLowerCase()) {
  'english' || 'eng' => 'en',
  'french' || 'fre' || 'fra' => 'fr',
  'spanish' || 'spa' => 'es',
  'german' || 'ger' || 'deu' => 'de',
  'japanese' || 'jpn' => 'ja',
  'hindi' || 'hin' => 'hi',
  'italian' || 'ita' => 'it',
  _ => language.toLowerCase(),
};
List<String> languageTokens(String language) =>
    switch (normalizeLanguage(language)) {
      'en' => ['english', 'eng', 'en'],
      'fr' => ['french', 'fre', 'fra', 'fr'],
      'es' => ['spanish', 'spa', 'es'],
      'de' => ['german', 'ger', 'deu', 'de'],
      'ja' => ['japanese', 'jpn', 'ja'],
      'hi' => ['hindi', 'hin', 'hi'],
      'it' => ['italian', 'ita', 'it'],
      _ => [language.toLowerCase()],
    };
