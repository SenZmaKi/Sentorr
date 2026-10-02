import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../player/models.dart';
import '../../components/motion.dart';
import '../../components/player_control.dart';
import '../../shared/pop_out_window.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'player_actions.dart';
import 'player_ui.dart';
import 'bar_parts.dart';
import 'next_peek.dart';
import 'player_value.dart';
import 'seek_bar.dart';
import 'volume_control.dart';

/// Scrubber over one row of controls: transport and volume lead, where the
/// eye starts; captions, settings, queue and fullscreen trail.
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
    final s = player.stream;
    final next = queue?.next;
    return LayoutBuilder(
      builder: (context, box) => _bar(context, ui, s, next, box.maxWidth),
    );
  }

  Widget _bar(
    BuildContext context,
    PlayerUi ui,
    PlayerStream s,
    PlaybackItem? next,
    double width,
  ) {
    // Sized by the player, not the window: it shrinks while docking.
    final compact = width < 720;
    final inner = width - (compact ? Space.s16 : Space.s32);
    return MouseRegion(
      onEnter: (_) => ui.hovering = true,
      onExit: (_) => ui.hovering = false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? Space.s8 : Space.s16,
          0,
          compact ? Space.s8 : Space.s16,
          Space.s8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s8),
              child: _Scrubber(player: player, ui: ui),
            ),
            // While the player animates to or from its docked size the row
            // is briefly too wide; clip it rather than overflow. The box is
            // pinned to the control height: OverflowBox takes its parent's
            // maximum, which is unbounded here.
            SizedBox(
              height: PlayerMetrics.control,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  maxWidth: inner < 420 ? 420 : inner,
                  child: Row(
                    children: [
                      PlayerValue(
                        stream: s.playing,
                        initial: player.state.playing,
                        builder: (context, playing) => PlayerControl(
                          icon: Icons.play_arrow_rounded,
                          tooltip: playing ? 'Pause (k)' : 'Play (k)',
                          onPressed: () =>
                              actions.togglePlay(acknowledge: false),
                          child: PlayPauseGlyph(playing: playing),
                        ),
                      ),
                      if (queue?.previous != null && !compact)
                        PlayerControl(
                          icon: Icons.skip_previous_rounded,
                          tooltip: 'Previous (Shift+P)',
                          onPressed: actions.previous,
                        ),
                      if (next != null || queue?.canExtend == true)
                        NextControl(next: next, onPressed: actions.next),
                      PlayerValue(
                        stream: s.volume,
                        initial: player.state.volume,
                        builder: (context, volume) =>
                            VolumeControl(volume: volume, actions: actions),
                      ),
                      const SizedBox(width: Space.s8),
                      Clock(player: player),
                      Expanded(
                        child: queue == null
                            ? const SizedBox.shrink()
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: EpisodeChip(
                                  item: queue!.current,
                                  open: ui.panel == PlayerPanel.queue,
                                  onTap: queue!.items.length > 1
                                      ? () => ui.toggle(PlayerPanel.queue)
                                      : null,
                                ),
                              ),
                      ),
                      const SizedBox(width: Space.s16),
                      PlayerValue(
                        stream: s.rate,
                        initial: player.state.rate,
                        builder: (context, rate) => rate == 1
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(right: Space.s8),
                                child: RateBadge(
                                  label: rateLabel(rate),
                                  onTap: () => ui.toggle(PlayerPanel.settings),
                                ),
                              ),
                      ),
                      PlayerValue(
                        stream: s.track,
                        initial: player.state.track,
                        builder: (context, track) => PlayerControl(
                          icon: Icons.closed_caption_outlined,
                          tooltip: 'Captions (c)',
                          selected:
                              track.subtitle.id != 'no' &&
                              track.subtitle.id != 'auto',
                          onPressed: actions.toggleSubtitles,
                        ),
                      ),
                      PlayerControl(
                        icon: Icons.settings_outlined,
                        tooltip: 'Settings',
                        selected: ui.panel == PlayerPanel.settings,
                        onPressed: () => ui.toggle(PlayerPanel.settings),
                        child: AnimatedRotation(
                          turns: ui.panel == PlayerPanel.settings ? 0.125 : 0,
                          duration: reduceMotion(context)
                              ? Duration.zero
                              : Motion.panel,
                          curve: Motion.change,
                          child: const Icon(Icons.settings_outlined),
                        ),
                      ),
                      if (PopOutWindow.instance.supported && !compact)
                        PlayerControl(
                          icon: Icons.picture_in_picture_alt_rounded,
                          tooltip: 'Pop out',
                          onPressed: actions.popOut,
                        ),
                      PlayerControl(
                        icon: ui.fullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        tooltip: ui.fullscreen
                            ? 'Exit full screen (f)'
                            : 'Full screen (f)',
                        onPressed: actions.toggleFullscreen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "S1 E4 · Name" for episodes, the title for movies.
String itemLabel(PlaybackItem item) => item.isEpisode
    ? '${episodeCode(item.season, item.episode)} · ${item.name}'
    : item.name;

class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.player, required this.ui});

  final Player player;
  final PlayerUi ui;

  @override
  Widget build(BuildContext context) {
    final s = player.stream;
    return PlayerValue(
      stream: s.duration,
      initial: player.state.duration,
      builder: (context, duration) => PlayerValue(
        stream: s.buffer,
        initial: player.state.buffer,
        builder: (context, buffer) => PlayerValue(
          stream: s.position,
          initial: player.state.position,
          builder: (context, position) => SeekBar(
            position: position,
            duration: duration,
            buffer: buffer,
            onSeek: player.seek,
            onScrubbing: (on) => ui.hovering = on,
          ),
        ),
      ),
    );
  }
}
