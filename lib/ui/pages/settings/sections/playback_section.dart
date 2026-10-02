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

class PlaybackSection extends ConsumerWidget {
  const PlaybackSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(settingsProvider.select((s) => s.torrents));
    final notifier = ref.read(settingsProvider.notifier);
    void edit(TorrentSettings Function(TorrentSettings) change) =>
        notifier.update((s) => s.copyWith(torrents: change(s.torrents)));
    return Column(
      children: [
        SettingsGroup(
          title: 'Choosing a torrent',
          description: 'What Sentorr looks for when you press Play',
          children: [
            SettingsTile(
              icon: Icons.high_quality_outlined,
              title: 'Preferred quality',
              subtitle: 'Closest available is used when this one is missing',
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
              keywords: 'peers availability',
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
          ],
        ),
        SettingsGroup(
          title: 'Starting playback',
          description: 'Close matches and misses always ask you first',
          children: [
            SettingsTile(
              icon: Icons.fact_check_outlined,
              title: 'Show the torrent before playing',
              subtitle: t.reviewExactMatches
                  ? 'An exact match counts down so you can pick another'
                  : 'Exact matches play straight away',
              trailing: SToggle(
                value: t.reviewExactMatches,
                semanticLabel: 'Show the torrent before playing',
                onChanged: (v) =>
                    edit((t) => t.copyWith(reviewExactMatches: v)),
              ),
            ),
            SettingsTile(
              icon: Icons.timer_outlined,
              title: 'Countdown',
              subtitle: 'How long an exact match waits before it plays',
              keywords: 'delay autoplay wait',
              enabled: t.reviewExactMatches,
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
