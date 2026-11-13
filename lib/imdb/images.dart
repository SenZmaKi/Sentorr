/// IMDb's image CDN renders sizes on request via the `._V1_` URL suffix.
/// Widths snap to a few steps so nearby layouts share cached files.
String imdbImageUrl(String url, {required double width}) {
  final match = _suffix.firstMatch(url);
  if (match == null) return url;
  final px = _steps.firstWhere((s) => s >= width, orElse: () => _steps.last);
  return '${url.substring(0, match.start)}._V1_QL75_UX${px}_.${match[1]}';
}

final _suffix = RegExp(r'\._V1_[^/]*\.(jpg|jpeg|png)$', caseSensitive: false);
const _steps = [180, 360, 540, 720, 1080, 1440, 1920, 2560];

/// Every other size of [url]'s image, nearest first, for an offline
/// fallback to whichever one is already on disk.
List<String> imdbImageRenditions(String url) {
  final match = _suffix.firstMatch(url);
  if (match == null) return const [];
  final size = RegExp(r'_UX(\d+)_').firstMatch(url);
  final current = size == null ? _steps.last : int.parse(size[1]!);
  final base = url.substring(0, match.start);
  return [
    for (final px in [
      ..._steps,
    ]..sort((a, b) => (a - current).abs().compareTo((b - current).abs())))
      if (px != current) '$base._V1_QL75_UX${px}_.${match[1]}',
  ];
}
