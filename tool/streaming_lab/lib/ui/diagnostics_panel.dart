import 'package:flutter/material.dart';
import 'package:sentorr/ui/components/surface.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../runtime/lab_controller.dart';

String formatBytes(num bytes) => bytes >= 1048576
    ? '${(bytes / 1048576).toStringAsFixed(1)} MiB'
    : '${(bytes / 1024).toStringAsFixed(0)} KiB';

class DiagnosticsPanel extends StatelessWidget {
  const DiagnosticsPanel({super.key, required this.lab});
  final LabController lab;
  @override
  Widget build(BuildContext context) {
    final data = lab.snapshot;
    final total = (data['fileSize'] as num?) ?? 0;
    final done = (data['fileBytes'] as num?) ?? 0;
    final samples = (data['pieceSamples'] as List?) ?? [];
    final metrics = <String, String>{
      'Source': data['mode'] as String? ?? 'No session',
      'File downloaded': '${formatBytes(done)} / ${formatBytes(total)}',
      'Download rate': '${formatBytes((data['downloadRate'] as num?) ?? 0)}/s',
      'Peers': '${data['peers'] ?? 0}',
      'HTTP bytes served': formatBytes((data['httpBytes'] as num?) ?? 0),
      'HTTP requests': '${data['requests'] ?? 0}',
      'Urgent pieces': '${data['urgentPieces'] ?? 0}',
      'Piece memory cache': formatBytes(
        (data['memoryCacheBytes'] as num?) ?? 0,
      ),
      'Player buffer end': '${lab.player.state.buffer.inSeconds}s',
      'Player state': lab.player.state.buffering
          ? 'Buffering'
          : lab.player.state.playing
          ? 'Playing'
          : 'Paused',
    };
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery diagnostics',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Space.s16),
          for (final metric in metrics.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.s4),
              child: Row(
                children: [
                  Expanded(child: Text(metric.key)),
                  Text(metric.value, style: context.type.technical),
                ],
              ),
            ),
          const SizedBox(height: Space.s16),
          Text(
            'Sampled piece availability',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: Space.s8),
          if (samples.isNotEmpty)
            Semantics(
              label: 'Sampled availability across the selected file',
              child: SizedBox(
                height: 24,
                child: Row(
                  children: [
                    for (final available in samples)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0.5),
                          child: ColoredBox(
                            color: available == true
                                ? context.colors.action
                                : context.colors.surfaceInset,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Space.s8),
          Text(
            'Samples are not a playable time range. The player and torrent buffers are separate.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Space.s16),
          Text('Recent events', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Space.s8),
          Surface(
            depth: SurfaceDepth.inset,
            padding: const EdgeInsets.all(Space.s12),
            child: SizedBox(
              height: 150,
              child: ListView(
                reverse: true,
                children: lab.events.reversed
                    .take(20)
                    .map(
                      (event) => Text(
                        '${event['elapsedMs']} ms · ${event['event']} ${event['message'] ?? event['targetMs'] ?? ''}',
                        style: context.type.technical,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
