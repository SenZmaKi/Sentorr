import '../../imdb/models.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String kindLabel(ImdbTitle t) => switch (t.typeId) {
  'movie' => 'Movie',
  'tvSeries' => 'Series',
  'tvMiniSeries' => 'Limited series',
  _ => t.type ?? 'Title',
};

String? yearLabel(ImdbTitle t) {
  final start = t.releaseYear;
  if (start == null) return null;
  if (t.canHaveEpisodes != true) return '$start';
  final end = t.endYear;
  // A null end year is not proof a series is ongoing; show the start only.
  return end == null || end == start ? '$start' : '$start–$end';
}

String durationLabel(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  return h == 0 ? '$m min' : (m == 0 ? '$h h' : '$h h $m min');
}

String episodeCode(int? season, int? episode) =>
    ['S${season ?? '?'}', if (episode != null) 'E$episode'].join(' ');

/// "Today", "Yesterday", weekday within a week, else "Sep 17".
String relativeDay(DateTime date) {
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) {
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][date.weekday - 1];
  }
  final month = _months[date.month - 1];
  return date.year == now.year
      ? '$month ${date.day}'
      : '$month ${date.day}, ${date.year}';
}

/// "2.7M", "78K", "940".
String compactCount(int n) {
  String trim(double v) => v >= 10
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  if (n >= 1000000) return '${trim(n / 1000000)}M';
  if (n >= 1000) return '${trim(n / 1000)}K';
  return '$n';
}

/// "1.4 GB", "700 MB": binary units, one decimal below ten.
String sizeLabel(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final n = i == 0 || v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '$n ${units[i]}';
}

/// Player-style clock: "48:12" or "1:34:00".
String clockLabel(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// Duration stamp on artwork: "52m", "1h 34m".
String stampLabel(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  return h == 0 ? '${m}m' : '${h}h ${m}m';
}

/// "12,480": exact counts people read rather than compare at a glance.
String groupedCount(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// How long a title runs: a movie's runtime, or a series' season count
/// once its details are known.
String? lengthLabel(ImdbTitle t, [ImdbTitleDetails? details]) {
  if (t.canHaveEpisodes == true) {
    final n = details?.seasons.length ?? 0;
    return n == 0 ? null : (n == 1 ? '1 season' : '$n seasons');
  }
  final s = t.runtimeSeconds;
  return s == null ? null : durationLabel(Duration(seconds: s));
}

/// "Mar 4, 2024": a full calendar date, for facts rather than recency.
String dateLabel(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
