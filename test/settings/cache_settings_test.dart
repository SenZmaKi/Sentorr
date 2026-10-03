import 'package:sentorr/settings/models.dart';
import 'package:sentorr/shared/net/cache_tiers.dart';
import 'package:test/test.dart';

void main() {
  test('cache TTLs round-trip and fall back on invalid values', () {
    final edited = const CacheSettings().withTtl(CacheTier.catalogue, 90);
    final restored = AppSettings.fromJson(AppSettings(cache: edited).toJson())
        .cache;
    expect(restored.ttl(CacheTier.catalogue), const Duration(minutes: 90));
    expect(restored.ttl(CacheTier.liveSearch), CacheTier.liveSearch.defaultTtl);

    final invalid = CacheSettings.fromJson({
      'ttlMinutes': {'reference': 0, 'liveSearch': 'soon'},
    });
    expect(invalid.ttl(CacheTier.reference), CacheTier.reference.defaultTtl);
    expect(invalid.ttl(CacheTier.liveSearch), CacheTier.liveSearch.defaultTtl);
  });

  test('the network cache limit survives TTL edits and round-trips', () {
    final edited = const CacheSettings()
        .withMaxBytes(0)
        .withTtl(CacheTier.reference, 60);
    expect(edited.maxBytes, 0);
    expect(CacheSettings.fromJson(edited.toJson()).maxBytes, 0);
    expect(
      CacheSettings.fromJson({'maxBytes': -1}).maxBytes,
      CacheSettings.defaultMaxBytes,
    );
  });
}
