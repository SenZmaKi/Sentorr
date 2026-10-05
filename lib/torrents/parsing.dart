import 'models.dart';
import 'diagnostics.dart';
import 'release_metadata.dart';
import 'batch_matching.dart';

int? integer(Object? value) => int.tryParse('$value');

/// HTTP metadata cache for APIBay and older saved releases without URLs.
Uri torrentCacheUrl(String hash) =>
    Uri.parse('https://itorrents.org/torrent/${hash.toUpperCase()}.torrent');

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
  ).firstMatch(text.replaceAll(RegExp(r'[._]'), ' '));
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
  r'\b(?:(?:s(\d{1,2})|season\s*(\d{1,2}))(?:\s*(?:e|episode\s*)(\d{1,3})(?!\d))?|(\d{1,2})x(\d{1,3}))\b',
  caseSensitive: false,
);
final _marker = RegExp(
  r'\b(?:s\d{1,2}(?:e\d{1,3})?|seasons?\s*\d{1,2}|complete|entire|all\s+seasons|\d{1,2}x\d{1,3}|(?:19|20)\d{2}|2160p|1080p|720p|480p|4k|uhd|bluray|brrip|bdrip|webrip|web-dl|hdtv|x264|x265)\b',
  caseSensitive: false,
);

bool matchesRelease(
  TorrentQuery query,
  String name, {
  bool trustedIdentity = false,
}) => releaseRejection(query, name, trustedIdentity: trustedIdentity) == null;

TorrentRejection? releaseRejection(
  TorrentQuery query,
  String name, {
  bool trustedIdentity = false,
}) {
  final clean = name
      .replaceAll(RegExp(r'\[[^\]]*\]'), '')
      .replaceAll(RegExp(r'[._]'), ' ')
      .trim();
  final seasons = _season.allMatches(clean).toList();
  if (query.searchSeriesPacks) {
    final rejection = seriesBatchRejection(
      clean,
      query.season!,
      title: query.title,
    );
    if (rejection != null) return rejection;
  } else if (query.isSeries) {
    final metadata = ReleaseMetadata.parse(name);
    // Multi-season/range/multi-episode releases need a richer parser; fail closed.
    if (seasons.length != 1 ||
        RegExp(
          r'\b(?:s\d+|e\d+)\s*[-–]\s*(?:s|e)?\d+|e\d+e\d+',
          caseSensitive: false,
        ).hasMatch(clean)) {
      return TorrentRejection.ambiguousEpisodes;
    }
    final s = seasons.single;
    // Reject ranges and additional episode markers even in long-form names.
    if (RegExp(
      r'^\s*(?:[-–]\s*(?:s|e|episode\s*)?\d|(?:e|episode\s*)\d|\d{1,2}x\d)',
      caseSensitive: false,
    ).hasMatch(clean.substring(s.end))) {
      return TorrentRejection.ambiguousEpisodes;
    }
    if (metadata.seasons.length > 1 || metadata.episodes.length > 1) {
      return TorrentRejection.ambiguousEpisodes;
    }
    if (metadata.seasons.singleOrNull != query.season) {
      return TorrentRejection.seasonMismatch;
    }
    final episode = metadata.episodes.singleOrNull;
    if (query.isSeasonPack ? episode != null : episode != query.episode) {
      return TorrentRejection.episodeMismatch;
    }
  } else if (seasons.isNotEmpty) {
    return TorrentRejection.seasonMismatch;
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
    return TorrentRejection.titleMismatch;
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
    return TorrentRejection.yearMismatch;
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
      return TorrentRejection.titleMismatch;
    }
    final exact = _normalize(title) == _normalize(query.title);
    if (!exact &&
        (RegExp(r'\d').hasMatch(query.title) ||
            _normalize(query.title).length < 8 ||
            titleSimilarity(query.title, title) < .88)) {
      return TorrentRejection.titleMismatch;
    }
  }
  if (query.languages.isNotEmpty) {
    // Keep bracketed language hints, but never count language words in titles.
    final raw = name.replaceAll(RegExp(r'[._]'), ' ');
    final metadata = _marker
        .allMatches(raw)
        .where(
          (m) => !_normalize(query.title).startsWith(
            _normalize(
              raw.substring(0, m.end).replaceAll(RegExp(r'\[[^\]]*\]'), ''),
            ),
          ),
        )
        .firstOrNull;
    if (metadata == null) return TorrentRejection.languageUnconfirmed;
    // A subtitles-only marker cannot establish the preferred audio language.
    final lower = raw
        .substring(metadata.start)
        .toLowerCase()
        .replaceAll(
          RegExp(r'\b(?:subs?|subtitles|subbed)\b\s*[:=-]?\s*\w+\b'),
          '',
        )
        .replaceAll(RegExp(r'\b\w+\s+(?:subs?|subtitles|subbed)\b'), '');
    if (!query.languages.any(
      (language) => RegExp(
        '\\b(?:${languageTokens(language).map(RegExp.escape).join('|')})\\b',
      ).hasMatch(lower),
    )) {
      return TorrentRejection.languageUnconfirmed;
    }
  }
  return null;
}

DateTime? unixDate(Object? value) {
  final seconds = integer(value);
  if (seconds == null || seconds < 0 || seconds > 253402300799) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

String normalizeLanguage(String language) =>
    switch (language.trim().toLowerCase()) {
      'english' || 'eng' => 'en',
      'french' || 'fre' || 'fra' => 'fr',
      'spanish' || 'spa' => 'es',
      'german' || 'ger' || 'deu' => 'de',
      'japanese' || 'jpn' => 'ja',
      'hindi' || 'hin' => 'hi',
      'italian' || 'ita' => 'it',
      _ => language.trim().toLowerCase(),
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
      _ => [normalizeLanguage(language)],
    };

/// Resolve a provider's metadata link without accepting scripts or magnets.
Uri? torrentHttpUrl(Object? value, Uri endpoint) {
  if (value is! String || value.trim().isEmpty) return null;
  final relative = Uri.tryParse(value.trim());
  if (relative == null) return null;
  final uri = endpoint.resolveUri(relative);
  return (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty
      ? uri
      : null;
}
