import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../settings/notifier.dart';
import '../../../../torrents/filters.dart';
import '../../../../torrents/models.dart';
import '../../../components/source_icon.dart';
import '../../../components/toggle.dart';
import '../settings_group.dart';

String _about(TorrentSourceId id) => switch (id) {
  TorrentSourceId.pirateBay => 'Movies and series from a large general index',
  TorrentSourceId.yts => 'Movies only, small encodes',
  TorrentSourceId.bitsearch => 'Movies and series from a search aggregator',
};

class SourcesSection extends ConsumerWidget {
  const SourcesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(settingsProvider.select((s) => s.sources));
    final on = TorrentSourceId.values.where(sources.enabled).length;
    return SettingsGroup(
      title: 'Torrent sources',
      description: 'Sites searched together whenever you press Play',
      keywords: 'providers sites search',
      children: [
        for (final id in TorrentSourceId.values)
          SettingsTile(
            leading: SourceIcon(id),
            title: id.label,
            subtitle: sources.enabled(id) && on == 1
                ? '${_about(id)}. At least one source stays on'
                : _about(id),
            keywords: 'source provider',
            trailing: SToggle(
              value: sources.enabled(id),
              semanticLabel: 'Search ${id.label}',
              // The last source can't be turned off; nothing would be found.
              onChanged: sources.enabled(id) && on == 1
                  ? null
                  : (v) => ref
                        .read(settingsProvider.notifier)
                        .update(
                          (s) => s.copyWith(sources: s.sources.toggled(id, v)),
                        ),
            ),
          ),
      ],
    );
  }
}
