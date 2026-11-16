import 'package:flutter/material.dart';

import '../../library/integrity_result.dart';
import '../shared/theme/theme.dart';
import 'motion.dart';
import 'progress_track.dart';

/// A running download check as its stages, so a long hash shows movement:
/// each stage settles to a tick, and piece checking fills a track with an
/// estimate of the time left. [onMedia] draws with the player's colours.
class VerificationSteps extends StatefulWidget {
  const VerificationSteps({
    super.key,
    required this.progress,
    this.onMedia = false,
  });

  /// Null before the check reports, shown as its first stage.
  final IntegrityProgress? progress;
  final bool onMedia;

  @override
  State<VerificationSteps> createState() => _VerificationStepsState();
}

class _VerificationStepsState extends State<VerificationSteps> {
  static const _labels = {
    IntegrityStage.details: 'Fetch torrent details',
    IntegrityStage.file: 'Find the file on disk',
    IntegrityStage.pieces: 'Check every piece',
  };

  /// First hashing report, the baseline for the time estimate.
  ({DateTime at, double fraction})? _start;

  @override
  void initState() {
    super.initState();
    _track();
  }

  @override
  void didUpdateWidget(VerificationSteps old) {
    super.didUpdateWidget(old);
    _track();
  }

  void _track() {
    final fraction = widget.progress?.fraction;
    if (fraction == null) {
      _start = null;
    } else {
      _start ??= (at: DateTime.now(), fraction: fraction);
    }
  }

  /// e.g. "About 3 min left"; null until the rate has settled.
  String? _remaining(double fraction) {
    final start = _start;
    if (start == null) return null;
    final elapsed = DateTime.now().difference(start.at);
    final done = fraction - start.fraction;
    if (elapsed < const Duration(seconds: 3) || done < 0.01) return null;
    final left = elapsed * ((1 - fraction) / done);
    if (left < const Duration(minutes: 1)) return 'Less than a minute left';
    return 'About ${left.inMinutes + (left.inSeconds % 60 >= 30 ? 1 : 0)} '
        'min left';
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.progress?.stage ?? IntegrityStage.details;
    final fraction = widget.progress?.fraction;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final stage in IntegrityStage.values) ...[
          if (stage.index > 0) const SizedBox(height: Space.s12),
          _Step(
            label: _labels[stage]!,
            state: stage.index < current.index
                ? _StepState.done
                : stage == current
                ? _StepState.active
                : _StepState.pending,
            onMedia: widget.onMedia,
            trailing: stage == IntegrityStage.pieces && fraction != null
                ? '${(fraction * 100).floor()}%'
                : null,
          ),
          if (stage == IntegrityStage.pieces && stage == current)
            _PieceProgress(
              fraction: fraction,
              remaining: fraction == null ? null : _remaining(fraction),
              onMedia: widget.onMedia,
            ),
        ],
      ],
    );
  }
}

enum _StepState { done, active, pending }

/// Leading slot and gap, so details under a step align with its label.
const _indent = IconSizes.metadata + Space.s12;

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.state,
    required this.onMedia,
    this.trailing,
  });

  final String label;
  final _StepState state;
  final bool onMedia;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final (strong, quiet, faint) = _palette(context, onMedia);
    final color = switch (state) {
      _StepState.done => quiet,
      _StepState.active => strong,
      _StepState.pending => faint,
    };
    final leading = switch (state) {
      _StepState.done => Icon(
        Icons.check_rounded,
        size: IconSizes.metadata,
        color: quiet,
      ),
      _StepState.active when reduceMotion(context) => _Dot(
        color: strong,
        filled: true,
      ),
      _StepState.active => SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: strong,
          strokeCap: StrokeCap.round,
        ),
      ),
      _StepState.pending => _Dot(color: faint, filled: false),
    };
    return Semantics(
      liveRegion: state == _StepState.active,
      label: switch (state) {
        _StepState.done => '$label, done',
        _StepState.active =>
          '$label, in progress${trailing == null ? '' : ', $trailing'}',
        _StepState.pending => '$label, waiting',
      },
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox.square(
            dimension: IconSizes.metadata,
            child: Center(child: leading),
          ),
          const SizedBox(width: Space.s12),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: reduceMotion(context) ? Duration.zero : Motion.panel,
              style:
                  (state == _StepState.active
                          ? context.type.label
                          : context.type.bodySmall)
                      .copyWith(color: color),
              child: Text(label),
            ),
          ),
          if (trailing case final value?)
            Text(value, style: context.type.technical.copyWith(color: strong)),
        ],
      ),
    );
  }
}

/// The hashing track and time estimate, under the active pieces step.
class _PieceProgress extends StatelessWidget {
  const _PieceProgress({
    required this.fraction,
    required this.remaining,
    required this.onMedia,
  });

  final double? fraction;
  final String? remaining;
  final bool onMedia;

  @override
  Widget build(BuildContext context) {
    final (strong, quiet, _) = _palette(context, onMedia);
    final value = fraction ?? 0;
    return Padding(
      padding: const EdgeInsets.only(left: _indent, top: Space.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Glides between the engine's half-second reports.
          TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 500),
            builder: (context, v, _) => onMedia
                ? _MediaTrack(value: v, fill: strong)
                : ProgressTrack.value(v),
          ),
          const SizedBox(height: Space.s8),
          Text(
            remaining ??
                (fraction == null
                    ? 'Saving pending writes'
                    : 'Estimating time left'),
            style: context.type.caption.copyWith(color: quiet),
          ),
        ],
      ),
    );
  }
}

/// [ProgressTrack]'s inset reads poorly on a scrim; the player's own track
/// colours do not.
class _MediaTrack extends StatelessWidget {
  const _MediaTrack({required this.value, required this.fill});

  final double value;
  final Color fill;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(Radii.full),
    child: SizedBox(
      height: 4,
      child: ColoredBox(
        color: context.player.trackUnloaded,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0, 1),
          child: ColoredBox(color: fill),
        ),
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? color : null,
      border: filled ? null : Border.all(color: color, width: Borders.edge),
    ),
  );
}

(Color, Color, Color) _palette(BuildContext context, bool onMedia) => onMedia
    ? (
        context.player.foreground,
        context.player.foregroundSecondary,
        context.player.foregroundMuted,
      )
    : (
        context.colors.foreground,
        context.colors.foregroundSecondary,
        context.colors.foregroundMuted,
      );
