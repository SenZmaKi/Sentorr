import '../../torrents/models.dart';

/// Only endpoints may change remotely. Parsing behavior stays in the app.
class SourceDirectory {
  const SourceDirectory(this.version, this.expiresAt, this.endpoints);
  final int version;
  final DateTime expiresAt;
  final Map<TorrentSourceId, String> endpoints;

  factory SourceDirectory.defaults() =>
      SourceDirectory(0, DateTime.utc(2100), const {
        TorrentSourceId.pirateBay: 'https://apibay.org/q.php',
        TorrentSourceId.yts:
            'https://movies-api.accel.li/api/v2/list_movies.json',
        TorrentSourceId.bitsearch: 'https://bitsearch.eu/search',
        TorrentSourceId.nyaa: 'https://nyaa.si/',
      });

  factory SourceDirectory.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    final sources = json['sources'];
    if (version is! int ||
        version < 1 ||
        expiresAt == null ||
        !expiresAt.isAfter(DateTime.now().toUtc()) ||
        sources is! Map) {
      throw const FormatException('Invalid or expired source directory');
    }
    final endpoints = <TorrentSourceId, String>{};
    for (final id in TorrentSourceId.values) {
      final entry = sources[id.name];
      // Older signed directories predate specialized sources.
      if (entry == null && id == TorrentSourceId.nyaa) {
        endpoints[id] = SourceDirectory.defaults().endpoints[id]!;
        continue;
      }
      if (entry is! Map ||
          entry['apiEntryPoint'] is! String ||
          entry['allowedHosts'] is! List) {
        throw FormatException('Missing source endpoint: ${id.name}');
      }
      final endpoint = entry['apiEntryPoint'] as String;
      final uri = Uri.tryParse(endpoint);
      final hosts = entry['allowedHosts'] as List;
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasPort ||
          uri.hasFragment ||
          hosts.isEmpty ||
          hosts.length > 8 ||
          hosts.any(
            (h) => h is! String || !RegExp(r'^[a-z0-9.-]+$').hasMatch(h),
          ) ||
          !hosts.contains(uri.host)) {
        throw FormatException('Invalid source endpoint: ${id.name}');
      }
      endpoints[id] = endpoint;
    }
    return SourceDirectory(
      version,
      expiresAt.toUtc(),
      Map.unmodifiable(endpoints),
    );
  }
}
