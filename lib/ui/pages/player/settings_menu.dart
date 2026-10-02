import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../player/sleep_timer.dart';
import '../../components/motion.dart';
import '../../shared/theme/theme.dart';
import 'menu_rows.dart';
import 'player_actions.dart';
import 'player_value.dart';

enum _Page { root, speed, audio, subtitles, sleep }

/// Player settings, one level deep like YouTube's: speed, audio and
/// subtitle tracks, and a sleep timer. Track choices persist across items.
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
  Widget build(BuildContext context) {
    final p = widget.player;
    return PlayerMenuSurface(
      width: PlayerMetrics.menuWidth,
      child: AnimatedSize(
        duration: reduceMotion(context) ? Duration.zero : Motion.panel,
        curve: Motion.change,
        alignment: Alignment.bottomCenter,
        child: PlayerValue(
          stream: p.stream.tracks,
          initial: p.state.tracks,
          builder: (context, tracks) => PlayerValue(
            stream: p.stream.track,
            initial: p.state.track,
            builder: (context, track) => PlayerValue(
              stream: p.stream.rate,
              initial: p.state.rate,
              builder: (context, rate) => Column(
                mainAxisSize: MainAxisSize.min,
                children: switch (_page) {
                  _Page.root => _root(tracks, track, rate),
                  _Page.speed => _speed(rate),
                  _Page.audio => _audio(tracks, track),
                  _Page.subtitles => _subtitles(tracks, track),
                  _Page.sleep => _sleep(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _root(Tracks tracks, Track track, double rate) {
    final audio = _realAudio(tracks);
    final subs = _realSubs(tracks);
    final timer = ref.watch(sleepTimerProvider);
    return [
      PlayerMenuRow(
        icon: Icons.speed_rounded,
        label: 'Playback speed',
        value: rateLabel(rate),
        chevron: true,
        onTap: () => _go(_Page.speed),
      ),
      if (audio.length > 1)
        PlayerMenuRow(
          icon: Icons.audiotrack_outlined,
          label: 'Audio',
          value: _isReal(track.audio.id) ? audioLabel(track.audio) : 'Auto',
          chevron: true,
          onTap: () => _go(_Page.audio),
        ),
      PlayerMenuRow(
        icon: Icons.subtitles_outlined,
        label: 'Subtitles',
        value: subs.isEmpty
            ? 'None available'
            : _isReal(track.subtitle.id)
            ? subtitleLabel(track.subtitle)
            : 'Off',
        chevron: subs.isNotEmpty,
        onTap: subs.isEmpty ? null : () => _go(_Page.subtitles),
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
        selected: track.audio.id == t.id,
        onTap: () => widget.player.setAudioTrack(t),
      ),
  ];

  List<Widget> _subtitles(Tracks tracks, Track track) => [
    PlayerMenuHeader(title: 'Subtitles', onBack: () => _go(_Page.root)),
    PlayerMenuRow(
      label: 'Off',
      selected: !_isReal(track.subtitle.id),
      onTap: () => widget.player.setSubtitleTrack(SubtitleTrack.no()),
    ),
    for (final t in _realSubs(tracks))
      PlayerMenuRow(
        label: subtitleLabel(t),
        selected: track.subtitle.id == t.id,
        onTap: () => widget.player.setSubtitleTrack(t),
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
List<SubtitleTrack> _realSubs(Tracks t) =>
    t.subtitle.where((a) => _isReal(a.id)).toList();

String audioLabel(AudioTrack t) => _label(t.id, t.title, t.language);
String subtitleLabel(SubtitleTrack t) => _label(t.id, t.title, t.language);

/// "English · SDH", else the language, else the track number.
String _label(String id, String? title, String? code) {
  final language = _language(code);
  final parts = [?language, if (title != null && title != language) title];
  return parts.isEmpty ? 'Track $id' : parts.join(' · ');
}

String? _language(String? code) => switch (code?.toLowerCase()) {
  null || '' || 'und' => null,
  'en' || 'eng' => 'English',
  'es' || 'spa' => 'Spanish',
  'fr' || 'fre' || 'fra' => 'French',
  'de' || 'ger' || 'deu' => 'German',
  'it' || 'ita' => 'Italian',
  'pt' || 'por' => 'Portuguese',
  'ru' || 'rus' => 'Russian',
  'ja' || 'jpn' => 'Japanese',
  'ko' || 'kor' => 'Korean',
  'zh' || 'chi' || 'zho' => 'Chinese',
  'ar' || 'ara' => 'Arabic',
  'hi' || 'hin' => 'Hindi',
  'nl' || 'dut' || 'nld' => 'Dutch',
  'pl' || 'pol' => 'Polish',
  'tr' || 'tur' => 'Turkish',
  'sv' || 'swe' => 'Swedish',
  _ => code!.toUpperCase(),
};
