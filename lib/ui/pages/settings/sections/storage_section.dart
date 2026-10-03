import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/services.dart';
import '../../../../settings/notifier.dart';
import '../../../../shared/persistence/directory_size.dart';
import '../../../components/buttons.dart';
import '../../../components/confirm_dialog.dart';
import '../../../shared/title_format.dart';
import '../settings_controls.dart';
import '../settings_group.dart';

class _Usage {
  const _Usage(this.images, this.http);
  final int images, http;
}

class StorageSection extends ConsumerStatefulWidget {
  const StorageSection({super.key});

  @override
  ConsumerState<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends ConsumerState<StorageSection> {
  late Future<_Usage> _usage = _measure();

  Future<_Usage> _measure() async {
    final paths = ref.read(appPathsProvider);
    return _Usage(
      await directorySize(paths.imageCacheDirectory),
      await directorySize(paths.networkCacheDirectory),
    );
  }

  Future<void> _clear(
    String what,
    String message,
    Future<void> Function() action,
  ) async {
    final ok = await confirm(
      context,
      title: 'Clear $what?',
      message: message,
      confirmLabel: 'Clear',
    );
    if (!ok) return;
    await action();
    if (mounted) setState(() => _usage = _measure());
  }

  @override
  Widget build(BuildContext context) {
    final limit = ref.watch(
      settingsProvider.select((s) => s.imageCacheMaxBytes),
    );
    return FutureBuilder(
      future: _usage,
      builder: (context, snapshot) {
        final usage = snapshot.data;
        String size(int Function(_Usage) of) =>
            usage == null ? 'Measuring…' : sizeLabel(of(usage));
        return Column(
          children: [
            SettingsGroup(
              title: 'Cache',
              description:
                  'Kept so pages load faster. Clearing never touches '
                  'settings, progress or downloads; watched torrents are '
                  'cleared under Streaming',
              keywords: 'free space disk',
              children: [
                SettingsTile(
                  icon: Icons.image_outlined,
                  title: 'Image cache limit',
                  subtitle:
                      'Posters and backdrops; using ${size((u) => u.images)}',
                  keywords: 'artwork',
                  trailing: LimitField(
                    value: (limit / megabyte).round(),
                    presets: const {0: 'Unlimited'},
                    customDefault: 100,
                    min: 10,
                    unit: 'MB',
                    semanticLabel: 'Image cache limit',
                    onChanged: (n) => ref
                        .read(settingsProvider.notifier)
                        .update(
                          (s) => s.copyWith(imageCacheMaxBytes: n * megabyte),
                        ),
                  ),
                ),
                SettingsTile(
                  icon: Icons.hide_image_outlined,
                  title: 'Clear image cache',
                  subtitle:
                      '${size((u) => u.images)}; artwork downloads again as '
                      'you browse',
                  keywords: 'artwork',
                  trailing: SButton(
                    label: 'Clear',
                    onPressed: () => _clear(
                      'image cache',
                      'Artwork downloads again as you browse.',
                      () => ref.read(imageCacheProvider).emptyCache(),
                    ),
                  ),
                ),
                SettingsTile(
                  icon: Icons.http_rounded,
                  title: 'Clear network cache',
                  subtitle:
                      '${size((u) => u.http)}; catalog pages load fresh from '
                      'IMDb',
                  keywords: 'http responses catalog imdb',
                  trailing: SButton(
                    label: 'Clear',
                    onPressed: () => _clear(
                      'network cache',
                      'Catalog pages load fresh from IMDb next time.',
                      () => ref.read(networkClientProvider).clearCache(),
                    ),
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: 'Reset',
              description: 'Start over with Sentorr\'s defaults',
              children: [
                SettingsTile(
                  icon: Icons.restart_alt_rounded,
                  title: 'Reset settings',
                  subtitle:
                      'Every setting except the theme. Progress, followed '
                      'series and downloads stay',
                  keywords: 'defaults factory restore',
                  trailing: SButton.destructive(
                    label: 'Reset',
                    onPressed: () async {
                      final ok = await confirm(
                        context,
                        title: 'Reset settings?',
                        message:
                            'Every setting except the theme returns '
                            'to its default.',
                        confirmLabel: 'Reset',
                      );
                      if (ok) await ref.read(settingsProvider.notifier).reset();
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
