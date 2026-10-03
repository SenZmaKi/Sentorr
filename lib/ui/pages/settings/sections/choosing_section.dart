import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../settings/models.dart';
import '../../../../settings/notifier.dart';
import '../../../components/select.dart';
import '../../../components/toggle.dart';
import '../settings_controls.dart';
import '../settings_group.dart';

const _languages = {
  'en': 'English',
  'fr': 'French',
  'es': 'Spanish',
  'de': 'German',
  'it': 'Italian',
  'ja': 'Japanese',
  'hi': 'Hindi',
};

String _resolution(int r) => r == 2160 ? '2160p (4K)' : '${r}p';

/// How a torrent is picked for a title, whether it is played or downloaded,
/// and when you see the pick first.
class ChoosingSection extends ConsumerWidget {
  const ChoosingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(settingsProvider.select((s) => s.torrents));
    final reviewDownloads = ref.watch(
      settingsProvider.select((s) => s.downloads.reviewMatches),
    );
    final notifier = ref.read(settingsProvider.notifier);
    void edit(TorrentSettings Function(TorrentSettings) change) =>
        notifier.update((s) => s.copyWith(torrents: change(s.torrents)));
    return Column(
      children: [
        SettingsGroup(
          title: 'Choosing a torrent',
          description: 'What Sentorr looks for when you play or download',
          keywords: 'release pick match',
          children: [
            SettingsTile(
              icon: Icons.high_quality_outlined,
              title: 'Preferred quality',
              subtitle: 'The closest one is used when this isn\'t available',
              keywords: 'video hd uhd',
              trailing: ChoiceField<int>(
                value: t.preferredResolution,
                options: TorrentSettings.resolutions,
                labelOf: _resolution,
                semanticLabel: 'Preferred quality',
                onChanged: (r) =>
                    edit((t) => t.copyWith(preferredResolution: r)),
              ),
            ),
            SettingsTile(
              icon: Icons.translate_rounded,
              title: 'Audio languages',
              keywords: 'dubs tracks',
              subtitle: t.languages.isEmpty
                  ? 'Any language. Most releases don\'t name theirs, so '
                        'choosing one hides many results'
                  : 'Only releases that name one of these are offered',
              trailing: SizedBox(
                width: 168,
                child: SSelect<String>(
                  options: _languages.keys.toList(),
                  selected: t.languages,
                  labelOf: (code) => _languages[code] ?? code,
                  multiple: true,
                  placeholder: 'Any',
                  onClear: () => edit((t) => t.copyWith(languages: {})),
                  semanticLabel: 'Audio languages',
                  onSelected: (code) => edit(
                    (t) => t.copyWith(
                      languages: t.languages.contains(code)
                          ? ({...t.languages}..remove(code))
                          : {...t.languages, code},
                    ),
                  ),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.group_outlined,
              title: 'Minimum seeders',
              subtitle: 'Releases with fewer are never offered',
              keywords: 'peers availability health dead',
              trailing: LimitField(
                value: t.minimumSeeders,
                presets: const {1: 'Any'},
                customDefault: 5,
                min: 2,
                unit: 'seeders',
                semanticLabel: 'Minimum seeders',
                onChanged: (n) => edit((t) => t.copyWith(minimumSeeders: n)),
              ),
            ),
            SettingsTile(
              icon: Icons.layers_outlined,
              title: 'Consider season packs',
              subtitle: t.includeBatchCandidates
                  ? 'An episode can come from a whole season or series '
                        'torrent when it is better or better seeded'
                  : 'Episodes only come from single-episode torrents',
              keywords: 'batch complete series bundle',
              trailing: SToggle(
                value: t.includeBatchCandidates,
                semanticLabel: 'Consider season packs',
                onChanged: (v) =>
                    edit((t) => t.copyWith(includeBatchCandidates: v)),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Confirming a match',
          description:
              'Close matches and misses always wait for you; exact matches '
              'can go ahead on their own',
          keywords: 'review show before',
          children: [
            SettingsTile(
              icon: Icons.play_circle_outline_rounded,
              title: 'Before playing',
              subtitle: t.reviewExactMatches
                  ? 'An exact match counts down so you can pick another'
                  : 'An exact match plays straight away',
              keywords: 'show the torrent watch',
              trailing: SToggle(
                value: t.reviewExactMatches,
                semanticLabel: 'Show the torrent before playing',
                onChanged: (v) =>
                    edit((t) => t.copyWith(reviewExactMatches: v)),
              ),
            ),
            SettingsTile(
              icon: Icons.download_rounded,
              title: 'Before downloading',
              subtitle: reviewDownloads
                  ? 'Exact matches count down so you can pick others'
                  : 'Exact matches download straight away',
              keywords: 'show torrents season batch',
              trailing: SToggle(
                value: reviewDownloads,
                semanticLabel: 'Show torrents before downloading',
                onChanged: (v) => notifier.update(
                  (s) => s.copyWith(
                    downloads: s.downloads.copyWith(reviewMatches: v),
                  ),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.timer_outlined,
              title: 'Countdown',
              subtitle: 'How long an exact match waits for you',
              keywords: 'delay wait seconds',
              enabled: t.reviewExactMatches || reviewDownloads,
              trailing: NumberField(
                value: t.autoPlayDelaySeconds,
                min: TorrentSettings.minAutoPlayDelay,
                max: TorrentSettings.maxAutoPlayDelay,
                unit: 's',
                semanticLabel: 'Countdown seconds',
                onSubmitted: (n) =>
                    edit((t) => t.copyWith(autoPlayDelaySeconds: n)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
