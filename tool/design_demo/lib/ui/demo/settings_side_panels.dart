import 'package:flutter/material.dart';

import '../components/buttons.dart';
import '../components/overlays.dart';
import '../components/selection.dart';
import '../components/status.dart';
import '../components/surface.dart';
import '../shared/theme/theme.dart';

class StoragePanel extends StatelessWidget {
  const StoragePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stream cache',
                      style: context.type.subtitle.copyWith(
                        color: c.foreground,
                      ),
                    ),
                    const SizedBox(height: Space.s2),
                    Row(
                      spacing: Space.s8,
                      children: [
                        Text(
                          'Limit',
                          style: context.type.bodySmall.copyWith(
                            color: c.foregroundSecondary,
                          ),
                        ),
                        Text(
                          '50 GB',
                          style: context.type.technical.copyWith(
                            color: c.foreground,
                          ),
                        ),
                        const Tag('Auto clean'),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: ControlHeights.touch,
                height: ControlHeights.touch,
                decoration: BoxDecoration(
                  color: c.action,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.storage_rounded,
                  color: c.onAction,
                  size: IconSizes.navigation,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s24),
          const InsetProgress(
            value: 0.63,
            height: 14,
            semanticLabel: 'Cache used',
          ),
          const SizedBox(height: Space.s24),
          Center(
            child: Text(
              '31.4 GB',
              style: context.type.headline.copyWith(color: c.foreground),
            ),
          ),
          Center(
            child: Text(
              'used of 50 GB',
              style: context.type.bodySmall.copyWith(
                color: c.foregroundSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StreamingPanel extends StatefulWidget {
  const StreamingPanel({super.key});

  @override
  State<StreamingPanel> createState() => _StreamingPanelState();
}

class _StreamingPanelState extends State<StreamingPanel> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Surface(
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ChoiceCard(
                    title: 'Sequential',
                    description: 'Start fast, play in order',
                    leading: Icon(
                      Icons.play_circle_fill,
                      size: 48,
                      color: c.info,
                    ),
                    selected: _mode == 0,
                    onTap: () => setState(() => _mode = 0),
                  ),
                ),
                const SizedBox(width: Space.s16),
                Expanded(
                  child: ChoiceCard(
                    title: 'Balanced',
                    description: 'Better swarm health, slower start',
                    leading: Icon(Icons.bolt, size: 48, color: c.warning),
                    selected: _mode == 1,
                    onTap: () => setState(() => _mode = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.s16),
          Surface(
            depth: SurfaceDepth.raised,
            radius: Radii.panel,
            padding: const EdgeInsets.fromLTRB(
              Space.s16,
              Space.s12,
              Space.s12,
              Space.s12,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: IconSizes.control,
                  color: c.foregroundSecondary,
                ),
                const SizedBox(width: Space.s12),
                Expanded(
                  child: Text(
                    'Paste a magnet link to stream it directly',
                    style: context.type.label.copyWith(color: c.foreground),
                  ),
                ),
                SButton.primary(
                  label: 'Open',
                  onPressed: () =>
                      showSToast(context, message: 'Magnet added to queue'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
