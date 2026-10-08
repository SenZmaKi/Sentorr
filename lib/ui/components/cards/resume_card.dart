import 'package:flutter/material.dart';

import '../../shared/layout/adaptive.dart';
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
    this.nextEpisode = false,
    this.position,
    this.runtime,
    this.chip,
    this.chipIcon,
    this.onTap,
    this.preview,
    this.titleLink,
    this.metaLink,
    this.onRemove,
  });

  final String title;
  final List<MetaItem> meta;
  final Widget artwork;

  /// Fraction watched, 0–1.
  final double progress;

  /// An unstarted episode following one the viewer finished: the bar
  /// offers to start it instead of resuming.
  final bool nextEpisode;

  /// Where the viewer stopped and the file's length, as the player shows.
  final Duration? position, runtime;

  /// Top-left context, e.g. an episode code or the title kind.
  final String? chip;
  final IconData? chipIcon;
  final VoidCallback? onTap;

  /// Floating detail card shown while the pointer rests on the tile.
  final WidgetBuilder? preview;

  /// Independent title navigation, separate from playback.
  final Widget? titleLink;

  /// Independent episode navigation in the supporting line.
  final Widget? metaLink;

  /// Drops the card, from a control in its top-right corner shown on
  /// hover or focus, or always for touch.
  final VoidCallback? onRemove;

  static double textHeight(CardLines l) =>
      Space.s12 + l.body + Space.s2 + l.caption;

  Duration? get _left =>
      runtime == null || position == null ? null : runtime! - position!;

  @override
  Widget build(BuildContext context) {
    final left = _left;
    return HoverPreview(
      preview: preview,
      child: Interactive(
        borderRadius: Radii.card,
        onTap: onTap,
        excludeChildSemantics: titleLink == null && metaLink == null,
        semanticLabel: [
          nextEpisode ? 'Play next episode of $title' : 'Resume $title',
          if (!nextEpisode && left != null) '${clockLabel(left)} left',
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
                  if (onRemove != null &&
                      (!context.input.canHover || s.hovered || s.focused))
                    Positioned(
                      right: Space.s4,
                      top: Space.s4,
                      child: OverlayIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Remove from Continue watching',
                        onPressed: onRemove,
                      ),
                    ),
                  Positioned(
                    left: Space.s12,
                    right: Space.s12,
                    bottom: Space.s8,
                    child: _PlayerBar(
                      started: !nextEpisode,
                      progress: progress,
                      position: position,
                      runtime: runtime,
                      left: left,
                      active: s.hovered || s.focused,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.s12),
            titleLink ?? CardTitle(title, large: true),
            const SizedBox(height: Space.s2),
            metaLink ?? MetaLine(meta),
          ],
        ),
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.started,
    required this.progress,
    required this.position,
    required this.runtime,
    required this.left,
    required this.active,
  });

  /// False for a fresh episode: no position, clock or remaining time.
  final bool started;
  final double progress;
  final Duration? position, runtime, left;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final runtime = this.runtime, position = this.position;
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
                    started ? 'Resume' : 'Next episode',
                    style: type.label.copyWith(
                      color: OverlayColors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (runtime != null && (position != null || !started))
                    Text(
                      started
                          ? '${clockLabel(position!)} / ${clockLabel(runtime)}'
                          : clockLabel(runtime),
                      style: type.timecode.copyWith(
                        color: OverlayColors.foregroundSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (started && left != null)
              OverlayBadge('${clockLabel(left!)} left'),
          ],
        ),
        const SizedBox(height: Space.s8),
        _Scrubber(progress: started ? progress : 0, thumb: started),
      ],
    );
  }
}

/// Seek bar in the overlay roles: inactive track, white fill and a thumb
/// at the paused position. An unstarted episode shows the bare track.
class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.progress, this.thumb = true});

  final double progress;
  final bool thumb;

  @override
  Widget build(BuildContext context) {
    const knob = 10.0;
    return SizedBox(
      height: knob,
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
              if (thumb)
                Positioned(
                  left: (x - knob / 2).clamp(0, box.maxWidth - knob),
                  child: Container(
                    width: knob,
                    height: knob,
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
