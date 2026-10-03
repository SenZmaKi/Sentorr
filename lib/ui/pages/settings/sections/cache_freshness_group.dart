import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../settings/models.dart';
import '../../../../settings/notifier.dart';
import '../../../../shared/net/cache_tiers.dart';
import '../settings_controls.dart';
import '../settings_group.dart';

/// How long each kind of response is reused before Sentorr asks again.
class CacheFreshnessGroup extends ConsumerWidget {
  const CacheFreshnessGroup({super.key});

  static const _tiers = {
    CacheTier.liveSearch: (
      Icons.search_rounded,
      'Search results',
      'Title suggestions and torrent searches',
    ),
    CacheTier.catalogue: (
      Icons.movie_outlined,
      'Catalog pages',
      'Trending, titles, episodes, reviews and recommendations',
    ),
    CacheTier.reference: (
      Icons.menu_book_outlined,
      'Reference data',
      'Cast, crew and image galleries, which rarely change',
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(settingsProvider.select((s) => s.cache));
    return SettingsGroup(
      title: 'Cache freshness',
      description:
          'How long answers are reused before asking again. Older answers '
          'are kept for when you are offline',
      keywords: 'ttl duration age stale refresh network http',
      children: [
        for (final MapEntry(key: tier, value: (icon, title, subtitle))
            in _tiers.entries)
          SettingsTile(
            icon: icon,
            title: title,
            subtitle: subtitle,
            trailing: NumberField(
              value: cache.ttlMinutes(tier),
              min: 1,
              max: CacheSettings.maxTtlMinutes,
              unit: 'min',
              semanticLabel: '$title freshness in minutes',
              onSubmitted: (minutes) => ref
                  .read(settingsProvider.notifier)
                  .update(
                    (s) => s.copyWith(cache: s.cache.withTtl(tier, minutes)),
                  ),
            ),
          ),
      ],
    );
  }
}
