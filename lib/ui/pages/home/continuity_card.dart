import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../player/session.dart';
import '../../../sync/continuity/notifier.dart';
import '../../components/buttons.dart';
import '../../components/surface.dart';
import '../../shared/theme/theme.dart';
import 'home_layout.dart';

class ContinuityCard extends ConsumerWidget {
  const ContinuityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(continuityOffersProvider);
    final transfer = ref.watch(continuityTransferProvider);
    if (ref.watch(playerSessionProvider) != null ||
        (offers.isEmpty && !transfer.hasError)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: HomeLayout.of(context).insets.horizontal
          .copyWith(bottom: Space.s24),
      child: DepthBox(
        style: context.depth.of(SurfaceDepth.raised),
        radius: Radii.card,
        padding: const EdgeInsets.all(Space.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transfer.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s8),
                child: Text(
                  'Couldn’t continue here. ${transfer.error}',
                  style: context.type.bodySmall,
                ),
              ),
            for (final offer in offers) ...[
              Row(
                children: [
                  const Icon(Icons.devices_rounded, size: IconSizes.control),
                  const SizedBox(width: Space.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${offer.session.playing ? 'Playing' : 'Paused'} on ${offer.deviceName}',
                          style: context.type.bodySmall,
                        ),
                        Text(
                          offer.session.media.item.label,
                          style: context.type.subtitle,
                        ),
                        Text(
                          _clock(offer.session.position),
                          style: context.type.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss continuity suggestion',
                    onPressed: transfer.isLoading
                        ? null
                        : () => ref
                              .read(continuityOffersProvider.notifier)
                              .dismiss(offer),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: Space.s8),
              SButton(
                label: transfer.isLoading ? 'Preparing…' : 'Continue here',
                icon: Icons.play_arrow_rounded,
                onPressed: transfer.isLoading
                    ? null
                    : () => ref
                          .read(continuityTransferProvider.notifier)
                          .take(offer),
              ),
              if (offers.last != offer) const SizedBox(height: Space.s16),
            ],
          ],
        ),
      ),
    );
  }
}

String _clock(Duration value) =>
    '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
