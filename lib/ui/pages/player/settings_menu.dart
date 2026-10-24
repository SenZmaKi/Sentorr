import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../player/sleep_timer.dart';
import '../../components/buttons.dart';
import '../../components/section_header.dart';
import '../../shared/layout/adaptive.dart';
import '../../shared/theme/theme.dart';
import 'menu_rows.dart';
import 'audio_selection.dart';
import 'track_labels.dart';
import 'player_actions.dart';
import 'player_value.dart';
import 'player_layout.dart';
import 'screenshot_action.dart';

export 'track_labels.dart' show audioLabel, subtitleLabel;

enum _Page { root, speed, audio, subtitles, sleep }

/// Player settings, one level deep like YouTube's: speed, audio and
/// subtitle tracks, and a sleep timer. Audio language defaults apply to each file.
class SettingsMenu extends ConsumerStatefulWidget {
  const SettingsMenu({super.key, required this.player, required this.actions});

  final Player player;
  final PlayerActions actions;

  @override
  ConsumerState<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends ConsumerState<SettingsMenu> {
  _Page _page = _Page.root;

  void _go(_Page page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.actions.captions,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final p = widget.player;
    final dense = context.playerLayout.handheld;
    final popup = !widget.actions.ui.fullscreen;
    return PlayerMenuSurface(
      padding: EdgeInsets.all(dense ? Space.s12 : Space.s16),
      child: Column(
        mainAxisSize: popup ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            icon: Icons.settings_outlined,
            title: 'Settings',
            action: SIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close settings',
              onPressed: widget.actions.ui.closePanel,
            ),
          ),
          SizedBox(height: dense ? Space.s8 : Space.s16),
          Flexible(
            fit: popup ? FlexFit.loose : FlexFit.tight,
            child: SingleChildScrollView(
              child: PlayerValue(
                stream: p.stream.tracks,
                initial: p.state.tracks,
                builder: (context, tracks) => PlayerValue(
                  stream: p.stream.track,
                  initial: p.state.track,
                  builder: (context, reportedTrack) => AudioSelection(
                    player: p,
                    tracks: tracks,
                    track: reportedTrack,
                    builder: (audio) => PlayerValue(
                      stream: p.stream.rate,
                      initial: p.state.rate,
                      builder: (context, rate) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: switch (_page) {
                          _Page.root => _root(
                            tracks,
                            reportedTrack.copyWith(audio: audio),
                            rate,
                          ),
                          _Page.speed => _speed(rate),
                          _Page.audio => _audio(
                            tracks,
                            reportedTrack.copyWith(audio: audio),
                          ),
                          _Page.subtitles => _subtitles(tracks, reportedTrack),
                          _Page.sleep => _sleep(),
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _root(Tracks tracks, Track track, double rate) {
    final audio = _realAudio(tracks);
    final captions = widget.actions.captions;
    final subs = captions.embedded;
    final count = subs.length + captions.files.where((f) => !f.failed).length;
    final available = subs.isNotEmpty || captions.files.isNotEmpty;
    final timer = ref.watch(sleepTimerProvider);
    return [
      PlayerMenuRow(
        icon: Icons.speed_rounded,
        label: 'Playback speed',
        value: rateLabel(rate),
        chevron: true,
        onTap: () => _go(_Page.speed),
      ),
      PlayerMenuRow(
        icon: Icons.audiotrack_outlined,
        label: 'Audio',
        value: _isReal(track.audio.id)
            ? audioLabel(track.audio)
            : '${audio.length} available',
        scrollValue: _isReal(track.audio.id),
        chevron: audio.isNotEmpty,
        onTap: audio.isNotEmpty ? () => _go(_Page.audio) : null,
      ),
      PlayerMenuRow(
        icon: Icons.subtitles_outlined,
        label: 'Subtitles',
        value: !captions.active
            ? '$count available'
            : captions.selected != null
            ? captions.selected!.ready
                  ? captions.selected!.label
                  : '${captions.selected!.label} · ${captions.selected!.status}'
            : _isReal(track.subtitle.id)
            ? subtitleLabel(track.subtitle)
            : 'On',
        scrollValue: captions.active,
        chevron: available,
        onTap: available ? () => _go(_Page.subtitles) : null,
      ),
      PlayerMenuRow(
        icon: Icons.bedtime_outlined,
        label: 'Sleep timer',
        value: switch (timer) {
          null => 'Off',
          SleepTimer(endOfItem: true) => 'End of video',
          SleepTimer(:final endsAt?) =>
            '${endsAt.difference(DateTime.now()).inMinutes + 1} min left',
          _ => 'On',
        },
        chevron: true,
        onTap: () => _go(_Page.sleep),
      ),
      ScreenshotAction(player: widget.player, actions: widget.actions),
      PlayerMenuRow(
        icon: Icons.analytics_outlined,
        label: 'Stats for nerds (D)',
        onTap: () {
          widget.actions.ui.toggleStats();
          widget.actions.ui.closePanel();
        },
      ),
      if (!context.input.isTouch)
        PlayerMenuRow(
          icon: Icons.keyboard_outlined,
          label: 'Keyboard shortcuts (?)',
          onTap: () => widget.actions.showShortcuts(context),
        ),
    ];
  }

  List<Widget> _speed(double rate) => [
    PlayerMenuHeader(title: 'Playback speed', onBack: () => _go(_Page.root)),
    for (final r in PlayerActions.rates)
      PlayerMenuRow(
        label: rateLabel(r),
        selected: (r - rate).abs() < 0.001,
        onTap: () => widget.actions.setRate(r),
      ),
  ];

  List<Widget> _audio(Tracks tracks, Track track) => [
    PlayerMenuHeader(title: 'Audio', onBack: () => _go(_Page.root)),
    for (final t in _realAudio(tracks))
      PlayerMenuRow(
        label: audioLabel(t),
        scrollLabel: true,
        selected: track.audio.id == t.id,
        onTap: () => widget.actions.engine.streaming.audio.choose(t),
      ),
  ];

  List<Widget> _subtitles(Tracks tracks, Track track) => [
    PlayerMenuHeader(title: 'Subtitles', onBack: () => _go(_Page.root)),
    PlayerMenuRow(
      label: 'Off',
      selected: !widget.actions.captions.enabled,
      onTap: widget.actions.captions.off,
    ),
    for (final t in widget.actions.captions.embedded)
      PlayerMenuRow(
        label: subtitleLabel(t),
        scrollLabel: true,
        selected:
            widget.actions.captions.enabled &&
            widget.actions.captions.selectedFile == null &&
            track.subtitle.id == t.id,
        onTap: () => widget.actions.captions.chooseTrack(t),
      ),
    for (final f in widget.actions.captions.files)
      PlayerMenuRow(
        label: f.label,
        scrollLabel: true,
        value: f.ready ? null : f.status,
        selected:
            widget.actions.captions.enabled &&
            widget.actions.captions.selectedFile == f.file.index,
        onTap: f.failed
            ? null
            : () => widget.actions.captions.chooseFile(f.file.index),
      ),
  ];

  List<Widget> _sleep() {
    final timer = ref.watch(sleepTimerProvider);
    final notifier = ref.read(sleepTimerProvider.notifier);
    return [
      PlayerMenuHeader(title: 'Sleep timer', onBack: () => _go(_Page.root)),
      PlayerMenuRow(
        label: 'Off',
        selected: timer == null,
        onTap: notifier.cancel,
      ),
      for (final minutes in const [15, 30, 45, 60, 90])
        PlayerMenuRow(
          label: '$minutes minutes',
          selected: timer?.duration == Duration(minutes: minutes),
          onTap: () => notifier.set(Duration(minutes: minutes)),
        ),
      PlayerMenuRow(
        label: 'End of video',
        selected: timer?.endOfItem == true,
        onTap: notifier.endOfItem,
      ),
    ];
  }
}

bool _isReal(String id) => id != 'auto' && id != 'no';

List<AudioTrack> _realAudio(Tracks t) =>
    t.audio.where((a) => _isReal(a.id)).toList();
