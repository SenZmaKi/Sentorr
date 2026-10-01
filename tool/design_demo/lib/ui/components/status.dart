import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'surface.dart';

/// Determinate progress on a recessed track; null [value] shows buffering.
class InsetProgress extends StatelessWidget {
  const InsetProgress({super.key, required this.value, this.height = 12, this.semanticLabel});

  final double? value;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = context.depth;
    return Semantics(
      label: semanticLabel,
      value: value == null ? 'Buffering' : '${(value! * 100).round()}%',
      child: DepthBox(
        style: d.of(SurfaceDepth.inset),
        radius: Radii.full,
        height: height,
        padding: const EdgeInsets.all(2),
        child: value == null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(Radii.full),
                child: LinearProgressIndicator(minHeight: height, color: c.action, backgroundColor: Colors.transparent),
              )
            : LayoutBuilder(
                builder: (context, box) => Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: Motion.panel,
                    curve: Curves.easeInOut,
                    width: (box.maxWidth * value!.clamp(0, 1)).clamp(height - 4, box.maxWidth),
                    decoration: BoxDecoration(
                      color: c.action,
                      borderRadius: BorderRadius.circular(Radii.full),
                      boxShadow: d.of(SurfaceDepth.raised).shadows,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

enum TransferStatus { queued, paused, buffering, active, waiting, ready, failed }

/// Status label + icon + paired color roles; color is never the only cue.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final TransferStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, icon, fg, bg) = switch (status) {
      TransferStatus.queued => ('Queued', Icons.schedule, c.foregroundSecondary, c.surfaceInset),
      TransferStatus.paused => ('Paused', Icons.pause, c.foregroundSecondary, c.surfaceInset),
      TransferStatus.buffering => ('Buffering', Icons.hourglass_bottom, c.info, c.infoSurface),
      TransferStatus.active => ('Streaming', Icons.south, c.info, c.infoSurface),
      TransferStatus.waiting => ('Few peers', Icons.warning_amber, c.warning, c.warningSurface),
      TransferStatus.ready => ('Ready', Icons.check_circle_outline, c.success, c.successSurface),
      TransferStatus.failed => ('Failed', Icons.error_outline, c.error, c.errorSurface),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.s2, horizontal: Space.s8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: Space.s4),
          Text(
            label,
            style: context.type.caption.copyWith(color: fg, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Small neutral tag, e.g. quality labels.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.s2, horizontal: Space.s4 + Space.s2),
      decoration: BoxDecoration(
        color: c.surfaceControl,
        borderRadius: BorderRadius.circular(Radii.chip - 2),
        border: Border.all(color: c.borderSubtle),
      ),
      child: Text(
        label,
        style: context.type.caption.copyWith(color: c.foregroundSecondary, fontWeight: FontWeight.w500),
      ),
    );
  }
}
