import 'captions_control.dart';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../player/models.dart';
import '../../components/motion.dart';
import '../../components/player_control.dart';
import '../../shared/picture_in_picture.dart';
import '../../shared/screen_rotation.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'player_actions.dart';
import 'player_ui.dart';
import 'bar_fit.dart';
import 'bar_more.dart';
import 'bar_parts.dart';
import 'next_peek.dart';
import 'player_layout.dart';
import 'player_value.dart';
import 'seek_bar.dart';
import 'downloaded_track.dart';
import 'volume_control.dart';

/// Scrubber over one row of controls: transport and volume lead, where the
/// eye starts; captions, settings, queue and fullscreen trail. Controls the
/// row has no room for move, by priority, into a More menu ([fitBar]).
class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.player,
    required this.actions,
    required this.queue,
  });

  final Player player;
  final PlayerActions actions;
  final PlayQueue? queue;

  @override
  Widget build(BuildContext context) {
    final ui = PlayerUiScope.of(context);
    final layout = context.playerLayout;
    return MouseRegion(
      onEnter: (_) => ui.hovering = true,
      onExit: (_) => ui.hovering = false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          layout.barInset,
          0,
          layout.barInset,
          Space.s8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s8),
              child: _Scrubber(player: player, actions: actions, ui: ui),
            ),
            SizedBox(
              height: PlayerMetrics.control,
              // Sized by the player, not the window: it shrinks while
              // docking, when the row must give way rather than overflow.
              child: LayoutBuilder(
                builder: (context, box) => PlayerValue(
                  stream: player.stream.rate,
                  initial: player.state.rate,
                  builder: (context, rate) => PlayerValue(
                    stream: player.stream.duration,
                    initial: player.state.duration,
                    builder: (context, duration) => ClipRect(
                      child: _row(
                        context,
                        ui,
                        layout,
                        box.maxWidth,
                        rate,
                        duration,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    PlayerUi ui,
    PlayerLayout layout,
    double width,
    double rate,
    Duration duration,
  ) {
    final queue = this.queue;
    final next = queue?.next;
    final s = player.stream;
    final badge = rate == 1 ? null : rateLabel(rate);
    final fixed =
        PlayerMetrics.control +
        Space.s8 +
        _clockWidth(context, duration) +
        (badge == null ? 0 : _badgeWidth(context, badge));
    final fit = fitBar(
      width: width,
      fixed: fixed,
      available: {
        if (ScreenRotation.supported(context)) BarControl.rotate,
        BarControl.fullscreen,
        BarControl.settings,
        BarControl.captions,
        BarControl.torrents,
        if (queue != null) BarControl.episodes,
        if (next != null || queue?.canExtend == true) BarControl.next,
        if (queue?.previous != null) BarControl.previous,
        if (PictureInPicture.instance.supported) BarControl.popOut,
        if (layout.showVolume) BarControl.volume,
      },
    );
    bool has(BarControl c) => fit.shown.contains(c);
    final canOpenQueue = (queue?.items.length ?? 0) > 1;
    return Row(
      children: [
        PlayerValue(
          stream: s.playing,
          initial: player.state.playing,
          builder: (context, playing) => PlayerControl(
            icon: Icons.play_arrow_rounded,
            tooltip: playing ? 'Pause (k)' : 'Play (k)',
            onPressed: () => actions.togglePlay(acknowledge: false),
            child: PlayPauseGlyph(playing: playing),
          ),
        ),
        if (has(BarControl.previous))
          QueueControl(
            item: queue!.previous,
            previous: true,
            onPressed: actions.previous,
          ),
        if (has(BarControl.next))
          QueueControl(item: next, onPressed: actions.next),
        if (has(BarControl.volume))
          PlayerValue(
            stream: s.volume,
            initial: player.state.volume,
            builder: (context, volume) =>
                VolumeControl(volume: volume, actions: actions),
          ),
        const SizedBox(width: Space.s8),
        Clock(player: player),
        Expanded(
          child: has(BarControl.episodes)
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: EpisodeChip(
                    item: queue!.current,
                    open: ui.panel == PlayerPanel.queue,
                    onTap: canOpenQueue
                        ? () => ui.toggle(PlayerPanel.queue)
                        : null,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (has(BarControl.episodes)) const SizedBox(width: Space.s16),
        if (badge != null)
          Padding(
            padding: const EdgeInsets.only(right: Space.s8),
            child: RateBadge(
              label: badge,
              onTap: () => ui.toggle(PlayerPanel.settings),
            ),
          ),
        if (has(BarControl.captions)) CaptionsControl(actions: actions),
        if (has(BarControl.torrents))
          PlayerControl(
            icon: Icons.swap_horiz_rounded,
            tooltip: 'Torrents (t)',
            selected: ui.panel == PlayerPanel.torrents,
            onPressed: actions.toggleTorrents,
          ),
        if (has(BarControl.settings))
          PlayerControl(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            selected: ui.panel == PlayerPanel.settings,
            onPressed: () => ui.toggle(PlayerPanel.settings),
            child: AnimatedRotation(
              turns: ui.panel == PlayerPanel.settings ? 0.125 : 0,
              duration: reduceMotion(context) ? Duration.zero : Motion.panel,
              curve: Motion.change,
              child: const Icon(Icons.settings_outlined),
            ),
          ),
        if (has(BarControl.popOut))
          PlayerControl(
            icon: Icons.picture_in_picture_alt_rounded,
            tooltip: 'Pop out',
            onPressed: actions.popOut,
          ),
        if (fit.overflow.isNotEmpty)
          BarMore(
            controls: [
              for (final c in fit.overflow)
                if (c != BarControl.episodes || canOpenQueue) c,
            ],
            ui: ui,
            actions: actions,
            queue: queue,
          ),
        if (has(BarControl.rotate))
          PlayerControl(
            icon: Icons.screen_rotation_rounded,
            tooltip: 'Rotate',
            onPressed: () => actions.rotate(MediaQuery.orientationOf(context)),
          ),
        if (has(BarControl.fullscreen))
          PlayerControl(
            icon: ui.fullscreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            tooltip: ui.fullscreen ? 'Exit full screen (f)' : 'Full screen (f)',
            onPressed: actions.toggleFullscreen,
          ),
      ],
    );
  }

  /// The clock at its widest for [duration], at the current text scale.
  static double _clockWidth(BuildContext context, Duration duration) {
    final sample = clockLabel(duration).replaceAll(RegExp(r'\d'), '0');
    return _measure(context, '−$sample / $sample', context.type.timecode);
  }

  static double _badgeWidth(BuildContext context, String label) =>
      _measure(context, label, context.type.technical) + Space.s16 + Space.s8;

  static double _measure(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width.ceilToDouble();
  }
}

/// Captions are on when a real subtitle track is chosen.
bool captionsOn(Track track) =>
    track.subtitle.id != 'no' && track.subtitle.id != 'auto';

/// "S1 E4 · Name" for episodes, the title for movies.
String itemLabel(PlaybackItem item) => item.isEpisode
    ? '${episodeCode(item.season, item.episode)} · ${item.name}'
    : item.name;

class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.player,
    required this.actions,
    required this.ui,
  });

  final Player player;
  final PlayerActions actions;
  final PlayerUi ui;

  @override
  Widget build(BuildContext context) {
    final s = player.stream;
    return DownloadedTrack(
      status: actions.engine.streaming.status,
      cached: actions.engine.cacheRanges,
      builder: (context, downloaded) => PlayerValue(
        stream: s.duration,
        initial: player.state.duration,
        builder: (context, duration) => PlayerValue(
          stream: s.position,
          initial: player.state.position,
          builder: (context, position) => SeekBar(
            position: position,
            duration: duration,
            downloaded: downloaded,
            onSeek: actions.engine.seek,
            onScrubbing: (on) => ui.hovering = on,
          ),
        ),
      ),
    );
  }
}
