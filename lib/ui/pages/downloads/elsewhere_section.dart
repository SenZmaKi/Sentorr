import 'package:flutter/material.dart';

import '../../../following/models.dart';
import '../../../sync/elsewhere.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'elsewhere_row.dart';

/// What paired devices hold that this one does not, under each device's
/// name: their downloads under way on Ongoing, finished ones on Complete.
class ElsewhereSection extends StatelessWidget {
  const ElsewhereSection(
    this.devices, {
    super.key,
    required this.compact,
    this.first = false,
  });

  /// Each device's items for this tab; devices with none are left out.
  final List<DeviceHoldings> devices;
  final bool compact;

  /// Heads the tab, with nothing of this device's above it.
  final bool first;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, d)
          in devices.where((d) => d.items.isNotEmpty).indexed) ...[
        if (i > 0 || !first) const SizedBox(height: Space.s32),
        _DeviceHeader(d),
        for (final (i, e) in _ordered(d.items).indexed) ...[
          if (i > 0) const Divider(),
          ElsewhereRow(e, compact: compact),
        ],
      ],
    ],
  );

  /// Movies first, then each series' episodes in order.
  static List<Elsewhere> _ordered(List<Elsewhere> items) =>
      [...items]..sort((a, b) {
        final x = a.item, y = b.item;
        if (x.isEpisode != y.isEpisode) return x.isEpisode ? 1 : -1;
        final series = (x.series?.title ?? x.name).compareTo(
          y.series?.title ?? y.name,
        );
        if (series != 0) return series;
        return compareEpisodes(
          (season: x.season ?? 0, episode: x.episode ?? 0),
          (season: y.season ?? 0, episode: y.episode ?? 0),
        );
      });
}

/// The device's name, then how much it holds: "3 on their way", or
/// "12 downloads · 30 GB · plays from there".
class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader(this.device);

  final DeviceHoldings device;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = device.items;
    final n = items.length;
    final finished = items.every((e) => e.finished);
    final bytes = items.fold(0, (sum, e) => sum + e.size);
    final summary = finished
        ? [
            '$n download${n == 1 ? '' : 's'}',
            if (bytes > 0) sizeLabel(bytes),
            'plays from there',
          ].join(' · ')
        : '$n on ${n == 1 ? 'its' : 'their'} way';
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s12, 0, Space.s12, Space.s8),
      child: Row(
        children: [
          Icon(
            Icons.devices_rounded,
            size: IconSizes.control,
            color: c.foregroundSecondary,
          ),
          const SizedBox(width: Space.s8),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: device.name,
                    style: context.type.subtitle.copyWith(color: c.foreground),
                  ),
                  TextSpan(
                    text: '   $summary',
                    style: context.type.caption.copyWith(
                      color: c.foregroundMuted,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
