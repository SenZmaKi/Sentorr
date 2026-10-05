import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../settings/notifier.dart';
import '../../../../shared/source_directory/repository.dart';
import '../../../../torrents/filters.dart';
import '../../../../torrents/models.dart';
import '../../../components/buttons.dart';
import '../../../components/source_icon.dart';
import '../../../components/toggle.dart';
import '../settings_group.dart';

String _about(TorrentSourceId id) => switch (id) {
  TorrentSourceId.pirateBay => 'Movies and series from a large general index',
  TorrentSourceId.yts => 'Movies only, small encodes',
  TorrentSourceId.bitsearch => 'Movies and series from a search aggregator',
  TorrentSourceId.nyaa =>
    'English-translated anime, searched for Animation titles',
};

/// The sites searched, and the list of where to reach them.
class SourcesSection extends ConsumerWidget {
  const SourcesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(settingsProvider.select((s) => s.sources));
    final on = TorrentSourceId.values.where(sources.enabled).length;
    final directory = ref.watch(sourceDirectoryProvider);
    return SettingsGroup(
      title: 'Sources',
      description: 'Sites searched together for every play and download',
      keywords: 'torrent search',
      children: [
        for (final id in TorrentSourceId.values)
          SettingsTile(
            leading: SourceIcon(id),
            title: id.label,
            subtitle: sources.enabled(id) && on == 1
                ? '${_about(id)}. At least one source stays on'
                : _about(id),
            keywords: 'site search',
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
        SettingsTile(
          icon: Icons.dns_outlined,
          title: 'Site addresses',
          subtitle: directory.version == 0
              ? 'The built-in list; checked for moved sites at startup'
              : 'List version ${directory.version}; checked for moved sites '
                    'at startup',
          keywords: 'source directory endpoints domains mirrors blocked',
          trailing: SButton(
            label: 'Refresh',
            onPressed: () =>
                ref.read(sourceDirectoryProvider.notifier).refresh(),
          ),
        ),
      ],
    );
  }
}
