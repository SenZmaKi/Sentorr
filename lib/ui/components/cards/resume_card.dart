import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import '../artwork_frame.dart';
import '../hover_preview.dart';
import '../interactive.dart';
import 'card_parts.dart';

/// A paused player: the still carries the resume control, playback clock
/// and scrubber, so it is clear a click picks up where you left off.
class ResumeCard extends StatelessWidget {
  const ResumeCard({
    super.key,
    required this.title,
    required this.meta,
    required this.artwork,
    required this.progress,
    this.runtime,
    this.chip,
    this.chipIcon,
    this.onTap,
    this.preview,
  });

  final String title;
  final List<MetaItem> meta;
  final Widget artwork;

  /// Fraction watched, 0–1.
  final double progress;
  final Duration? runtime;

  /// Top-left context, e.g. an episode code or the title kind.
  final String? chip;
  final IconData? chipIcon;
  final VoidCallback? onTap;

  /// Floating detail card shown while the pointer rests on the tile.
  final WidgetBuilder? preview;

  static double textHeight(CardLines l) =>
      Space.s12 + l.body + Space.s2 + l.caption;

  Duration? get _left => runtime == null ? null : runtime! * (1 - progress);

  @override
  Widget build(BuildContext context) {
    final left = _left;
    return HoverPreview(
      preview: preview,
      child: Interactive(
        borderRadius: Radii.card,
        onTap: onTap,
        semanticLabel: [
          'Resume $title',
          if (left != null) '${durationLabel(left)} left',
        ].join(', '),
        builder: (context, s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ArtworkFrame(
                active: s.hovered || s.focused,
                artwork: artwork,
                scrim: true,
                decorations: [
                  if (chip != null)
                    Positioned(
                      left: Space.s12,
                      top: Space.s12,
                      child: OverlayBadge(chip!, icon: chipIcon),
                    ),
                  Positioned(
                    left: Space.s12,
                    right: Space.s12,
                    bottom: Space.s8,
                    child: _PlayerBar(
                      progress: progress,
                      runtime: runtime,
                      left: left,
                      active: s.hovered || s.focused,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.s12),
            CardTitle(title, large: true),
            const SizedBox(height: Space.s2),
            MetaLine(meta),
          ],
        ),
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.progress,
    required this.runtime,
    required this.left,
    required this.active,
  });

  final double progress;
  final Duration? runtime;
  final Duration? left;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final runtime = this.runtime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: Motion.hover,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: active
                    ? context.depth.of(SurfaceDepth.raised).shadows
                    : const [],
              ),
              child: const OverlayGlyph(
                Icons.play_arrow_rounded,
                primary: true,
              ),
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resume',
                    style: type.label.copyWith(
                      color: OverlayColors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (runtime != null)
                    Text(
                      '${clockLabel(runtime * progress)} / ${clockLabel(runtime)}',
                      style: type.technical.copyWith(
                        color: OverlayColors.foregroundSecondary,
                        fontSize: 12,
                        height: 16 / 12,
                      ),
                    ),
                ],
              ),
            ),
            if (left != null)
              OverlayBadge('${stampLabel(left!)} left', technical: true),
          ],
        ),
        const SizedBox(height: Space.s8),
        _Scrubber(progress: progress),
      ],
    );
  }
}

/// Seek bar in the overlay roles: inactive track, white fill and a thumb
/// at the paused position.
class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    const thumb = 10.0;
    return SizedBox(
      height: thumb,
      child: LayoutBuilder(
        builder: (context, box) {
          final x = box.maxWidth * progress.clamp(0, 1);
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: OverlayColors.inactiveTrack,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
              Container(
                width: x,
                height: 3,
                decoration: BoxDecoration(
                  color: OverlayColors.foreground,
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
              ),
              Positioned(
                left: (x - thumb / 2).clamp(0, box.maxWidth - thumb),
                child: Container(
                  width: thumb,
                  height: thumb,
                  decoration: const BoxDecoration(
                    color: OverlayColors.foreground,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
