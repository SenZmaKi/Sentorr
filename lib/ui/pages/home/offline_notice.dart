import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../home/downloaded.dart';
import '../../components/surface.dart';
import '../../shared/theme/theme.dart';

/// Heads the home page while offline. With something downloaded it is a
/// quiet status line over the downloads spotlight; with nothing, it says
/// how to have something to watch next time.
class OfflineNotice extends ConsumerWidget {
  const OfflineNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final empty = ref.watch(finishedDownloadsProvider).isEmpty;
    final status = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Offline',
            style: context.type.label.copyWith(color: c.foreground),
          ),
          TextSpan(
            text: empty
                ? '  ·  Reconnecting on its own'
                : '  ·  Showing what plays on this device. Everything else '
                      'returns when you reconnect.',
          ),
        ],
      ),
      style: context.type.bodySmall.copyWith(color: c.foregroundMuted),
    );
    final line = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Centres the icon on the first line of text.
          padding: const EdgeInsets.only(top: Space.s2),
          child: Icon(
            Icons.cloud_off_rounded,
            size: IconSizes.metadata,
            color: c.warning,
          ),
        ),
        const SizedBox(width: Space.s8),
        Expanded(child: status),
      ],
    );
    return Semantics(
      liveRegion: true,
      child: !empty
          ? line
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                line,
                const SizedBox(height: Space.s16),
                const Surface(child: _NothingDownloaded()),
              ],
            ),
    );
  }
}

class _NothingDownloaded extends StatelessWidget {
  const _NothingDownloaded();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        DepthBox(
          style: context.depth.of(SurfaceDepth.raised),
          radius: Radii.control,
          width: ControlHeights.standard,
          height: ControlHeights.standard,
          child: Icon(
            Icons.download_rounded,
            size: IconSizes.control,
            color: c.foregroundMuted,
          ),
        ),
        const SizedBox(width: Space.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nothing downloaded yet',
                style: context.type.subtitle.copyWith(color: c.foreground),
              ),
              const SizedBox(height: Space.s4),
              Text(
                'Download a movie or episode while you’re online and it '
                'plays here without a connection.',
                style: context.type.bodySmall.copyWith(
                  color: c.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
