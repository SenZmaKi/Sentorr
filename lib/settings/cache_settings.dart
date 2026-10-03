import '../shared/net/cache_tiers.dart';
import 'json.dart';

/// How long each kind of cached response stays fresh, in minutes, and how
/// much disk the network cache may use.
class CacheSettings {
  const CacheSettings({
    Map<CacheTier, int>? ttlMinutes,
    this.maxBytes = defaultMaxBytes,
  }) : _ttlMinutes = ttlMinutes ?? const {};

  static const maxTtlMinutes = 7 * 24 * 60;
  static const defaultMaxBytes = 50 * 1024 * 1024;

  /// Zero means unlimited.
  final int maxBytes;

  final Map<CacheTier, int> _ttlMinutes;

  int ttlMinutes(CacheTier tier) =>
      _ttlMinutes[tier] ?? tier.defaultTtl.inMinutes;

  Duration ttl(CacheTier tier) => Duration(minutes: ttlMinutes(tier));

  CacheSettings withTtl(CacheTier tier, int minutes) => CacheSettings(
    ttlMinutes: {..._ttlMinutes, tier: minutes},
    maxBytes: maxBytes,
  );

  CacheSettings withMaxBytes(int bytes) =>
      CacheSettings(ttlMinutes: _ttlMinutes, maxBytes: bytes);

  factory CacheSettings.fromJson(Map<String, dynamic> json) => CacheSettings(
    ttlMinutes: {
      for (final tier in CacheTier.values)
        tier: jsonInt(
          jsonObject(json['ttlMinutes'])[tier.name],
          tier.defaultTtl.inMinutes,
          min: 1,
          max: maxTtlMinutes,
        ),
    },
    maxBytes: jsonInt(json['maxBytes'], defaultMaxBytes),
  );

  Map<String, dynamic> toJson() => {
    'ttlMinutes': {
      for (final tier in CacheTier.values) tier.name: ttlMinutes(tier),
    },
    'maxBytes': maxBytes,
  };
}
