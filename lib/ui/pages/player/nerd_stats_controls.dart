import 'package:flutter/material.dart';

import '../../../player/stats_recording.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// Stats for nerds are read against the picture, so like captions they keep
/// the dark overlay treatment in either brightness.
const statsSurface = OverlayColors.scrim;

class StatsIconButton extends StatelessWidget {
  const StatsIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = OverlayColors.foreground,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    color: color,
    hoverColor: PlayerColors.dark.stateHover,
    highlightColor: PlayerColors.dark.statePressed,
    icon: Icon(icon, size: 18),
  );
}

/// Pulsing dot and elapsed time while a recording runs.
class RecordingBadge extends StatelessWidget {
  const RecordingBadge({super.key, required this.recording});
  final StatsRecording recording;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        recording.stopped
            ? Icons.stop_rounded
            : Icons.fiber_manual_record_rounded,
        size: 12,
        color: recording.stopped
            ? OverlayColors.foregroundSecondary
            : OverlayColors.recording,
      ),
      const SizedBox(width: Space.s4),
      Text(
        clockLabel(recording.elapsed),
        style: context.type.technical.copyWith(color: OverlayColors.foreground),
      ),
    ],
  );
}

/// What remains of the readout once hidden mid-recording; reopens it.
class RecordingChip extends StatelessWidget {
  const RecordingChip({
    super.key,
    required this.recording,
    required this.onOpen,
  });

  final StatsRecording recording;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
    color: statsSurface,
    borderRadius: BorderRadius.circular(Radii.full),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(Radii.full),
      child: Tooltip(
        message: 'Show stats for nerds',
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s12,
            vertical: Space.s4,
          ),
          child: RecordingBadge(recording: recording),
        ),
      ),
    ),
  );
}

/// Shown once a recording stops: send it somewhere or drop it.
class RecordingExportBar extends StatelessWidget {
  const RecordingExportBar({
    super.key,
    required this.recording,
    required this.onCopy,
    required this.onSave,
    required this.onDiscard,
  });

  final StatsRecording recording;
  final VoidCallback onCopy, onSave, onDiscard;

  @override
  Widget build(BuildContext context) {
    final button =
        TextButton.styleFrom(
          foregroundColor: OverlayColors.foreground,
          visualDensity: VisualDensity.compact,
          textStyle: context.type.label,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.pressed)
                ? PlayerColors.dark.statePressed
                : PlayerColors.dark.stateHover,
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: Space.s8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.s4,
        children: [
          Text(
            recording.elapsed < const Duration(seconds: 1)
                ? 'Last ${recording.preRoll.inMinutes} minutes of playback'
                : 'Recorded ${clockLabel(recording.elapsed)} · '
                      '${recording.length} samples'
                      '${recording.segments > 1 ? ' · ${recording.segments} sources' : ''}',
            style: context.type.caption.copyWith(
              color: OverlayColors.foregroundSecondary,
            ),
          ),
          TextButton.icon(
            style: button,
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: const Text('Copy JSON'),
          ),
          TextButton.icon(
            style: button,
            onPressed: onSave,
            icon: const Icon(Icons.save_alt_rounded, size: 16),
            label: const Text('Save file'),
          ),
          TextButton(
            style: button,
            onPressed: onDiscard,
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
