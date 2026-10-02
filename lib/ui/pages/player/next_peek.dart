import 'package:flutter/material.dart';

import '../../../player/models.dart';
import '../../components/artwork_frame.dart';
import '../../components/interactive.dart';
import '../../components/motion.dart';
import '../../components/player_control.dart';
import '../../components/title_artwork.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'menu_rows.dart';

/// The Next control, which previews what it will play while pointed at,
/// as YouTube's does: a small floating card above the bar.
class NextControl extends StatefulWidget {
  const NextControl({super.key, required this.next, required this.onPressed});

  /// Null when the next season is still to be fetched.
  final PlaybackItem? next;
  final VoidCallback onPressed;

  @override
  State<NextControl> createState() => _NextControlState();
}

class _NextControlState extends State<NextControl> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  @override
  Widget build(BuildContext context) {
    final next = widget.next;
    return MouseRegion(
      onEnter: (_) => next == null ? null : _portal.show(),
      onExit: (_) => _portal.hide(),
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) => CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            offset: const Offset(-Space.s8, -Space.s12),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: IgnorePointer(child: _Peek(item: next!)),
            ),
          ),
          child: PlayerControl(
            icon: Icons.skip_next_rounded,
            tooltip: next == null ? 'Next season (Shift+N)' : 'Next (Shift+N)',
            // The peek card already says what Next plays.
            showTooltip: next == null,
            onPressed: widget.onPressed,
          ),
        ),
      ),
    );
  }
}

class _Peek extends StatelessWidget {
  const _Peek({required this.item});

  final PlaybackItem item;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      offset: Space.s4,
      child: PlayerMenuSurface(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.control),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    TitleArtwork(image: item.artwork),
                    if (item.isEpisode)
                      Positioned(
                        left: Space.s8,
                        top: Space.s8,
                        child: OverlayBadge(
                          episodeCode(item.season, item.episode),
                          technical: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.s4,
                Space.s8,
                Space.s4,
                Space.s4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next · Shift+N',
                    style: context.type.caption.copyWith(
                      color: context.colors.foregroundMuted,
                    ),
                  ),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.label.copyWith(
                      color: context.colors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What is playing, as a chip after the clock (YouTube puts the chapter
/// there). The one way to open the episodes or Up next panel, besides q.
class EpisodeChip extends StatelessWidget {
  const EpisodeChip({
    super.key,
    required this.item,
    required this.onTap,
    this.open = false,
  });

  final PlaybackItem item;
  final VoidCallback? onTap;

  /// The panel it opens is showing: keeps the fill and turns the chevron.
  final bool open;

  @override
  Widget build(BuildContext context) {
    final label = item.isEpisode
        ? '${episodeCode(item.season, item.episode)} · ${item.name}'
        : item.name;
    // When the bar is short of room the chip gives way entirely rather
    // than squeezing its label to nothing.
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < _minWidth
          ? const SizedBox.shrink()
          : _chip(context, label),
    );
  }

  static const _minWidth = 96.0;

  Widget _chip(BuildContext context, String label) {
    return Interactive(
      onTap: onTap,
      borderRadius: Radii.full,
      focusColor: context.player.focus,
      selected: onTap == null ? null : open,
      semanticLabel: onTap == null ? label : '$label, show queue (q)',
      builder: (context, s) => AnimatedContainer(
        duration: Motion.hover,
        height: 32,
        padding: const EdgeInsets.only(left: Space.s12, right: Space.s4),
        decoration: BoxDecoration(
          color: s.hovered || s.pressed || open
              ? context.player.stateHover
              : context.player.stateHover.clear,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('·  ', style: TextStyle(color: context.player.inactiveTrack)),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.label.copyWith(
                  color: context.player.foreground,
                ),
              ),
            ),
            if (onTap != null)
              AnimatedRotation(
                turns: open ? 0.25 : 0,
                duration: Motion.hover,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: IconSizes.control,
                  color: context.player.foregroundSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A non-default speed, shown so it is never forgotten; opens settings.
class RateBadge extends StatelessWidget {
  const RateBadge({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Interactive(
    onTap: onTap,
    borderRadius: Radii.chip,
    focusColor: context.player.focus,
    semanticLabel: 'Playback speed $label',
    builder: (context, s) => AnimatedContainer(
      duration: Motion.hover,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s8,
        vertical: Space.s2,
      ),
      decoration: BoxDecoration(
        color: s.hovered
            ? context.player.foregroundSecondary
            : context.player.foreground,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        label,
        style: context.type.technical.copyWith(
          color: context.player.onForeground,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}
