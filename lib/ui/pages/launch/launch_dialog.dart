import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../player/launch.dart';
import '../../../settings/notifier.dart';
import '../../../shared/net/online.dart';
import '../../../torrents/resolution_models.dart';
import '../../components/buttons.dart';
import '../../components/progress_track.dart';
import '../../components/adaptive_sheet.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';
import 'launch_states.dart';
import '../torrent_picker/torrent_option.dart';
import '../torrent_picker/torrent_picker.dart';

/// The torrent about to play, from the moment Play is pressed: a paired
/// device's copy counting down, searching, then an exact match counting
/// down, a close match to confirm, or a miss the viewer can help with. Any touch, scroll or key stops the countdown.
/// Pops itself once the launch ends.
class LaunchDialog extends ConsumerStatefulWidget {
  const LaunchDialog({super.key});

  @override
  ConsumerState<LaunchDialog> createState() => _LaunchDialogState();
}

class _LaunchDialogState extends ConsumerState<LaunchDialog>
    with SingleTickerProviderStateMixin {
  /// How long an exact match waits for the viewer before it plays. Built
  /// up front: a launch can end before any result touches it, and dispose
  /// must not be the first to, since it reads settings.
  late final AnimationController _countdown;
  final _title = TextEditingController();

  /// The paired device or the result last applied.
  Object? _shown;
  TorrentCandidate? _selected;
  bool _counting = false, _countdownSpent = false, _showAll = false;

  PlaybackLaunchNotifier get _launch =>
      ref.read(playbackLaunchProvider.notifier);

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(
      vsync: this,
      duration: ref.read(settingsProvider).torrents.autoActionDelay,
    )..addStatusListener(_onCountdown);
    final launch = ref.read(playbackLaunchProvider);
    if (launch != null) {
      _apply(launch);
    } else {
      // Ended before this mounted, e.g. a download playing at once.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    }
    ref.listenManual(playbackLaunchProvider, (_, next) {
      if (next == null) return _close();
      setState(() => _apply(next));
    });
  }

  @override
  void dispose() {
    _countdown.dispose();
    _title.dispose();
    super.dispose();
  }

  /// Takes in a new result; picks its best candidate and, for a paired
  /// device's copy or an exact match the viewer has not interrupted, starts
  /// counting down.
  void _apply(PlaybackLaunch launch) {
    final shown = launch.peer ?? launch.resolution;
    if (identical(shown, _shown)) return;
    _shown = shown;
    _title.text = launch.query?.title ?? _title.text;
    final match = launch.match;
    _selected = match?.candidate;
    _showAll = match != null && !match.exact;
    final ready = launch.peer != null || (match != null && match.exact);
    if (ready && !_countdownSpent) {
      _counting = true;
      _countdown.forward(from: 0);
    } else {
      _counting = false;
      _countdown.stop();
    }
  }

  void _onCountdown(AnimationStatus status) {
    if (status == AnimationStatus.completed && _counting) _play();
  }

  void _interrupt() {
    if (!_counting) return;
    _countdown.stop();
    setState(() {
      _counting = false;
      _countdownSpent = true;
    });
  }

  void _play() {
    if (ref.read(playbackLaunchProvider)?.peer != null) {
      return _launch.playFromPeer();
    }
    final selected = _selected;
    if (selected != null) _launch.play(selected);
  }

  /// Passing on the device's copy is no reason to hold an exact match back.
  void _streamInstead() {
    _countdownSpent = false;
    _launch.streamInstead();
  }

  void _close() {
    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final launch = ref.watch(playbackLaunchProvider);
    if (launch == null) return const SizedBox.shrink();
    final c = context.colors;
    final type = context.type;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _interrupt(),
      onPointerSignal: (_) => _interrupt(),
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, _) {
          _interrupt();
          return KeyEventResult.ignored;
        },
        // The host shows it as an adaptive sheet; the frame widens when
        // every torrent is listed.
        child: SheetFrame(
          maxWidth: _showAll ? 720 : 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _subject(launch),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.bodySmall.copyWith(color: c.foregroundMuted),
              ),
              const SizedBox(height: Space.s4),
              Text(
                _heading(launch),
                style: type.title.copyWith(color: c.foreground),
              ),
              const SizedBox(height: Space.s16),
              Flexible(child: _body(launch)),
              const SizedBox(height: Space.s24),
              if (_counting) ...[
                ProgressTrack(progress: _countdown),
                const SizedBox(height: Space.s16),
              ],
              // Rebuilt as the countdown ticks, for its seconds label.
              AnimatedBuilder(
                animation: _countdown,
                builder: (context, _) => LaunchActions(
                  onCancel: _launch.cancel,
                  secondary: launch.peer == null
                      ? null
                      : SButton(
                          label: 'Stream instead',
                          onPressed: _streamInstead,
                        ),
                  primary: _primary(launch),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The launch failed or found nothing because the device is offline.
  bool _offline(PlaybackLaunch launch) =>
      launch.peer == null &&
      !ref.watch(onlineProvider) &&
      (launch.error != null || (!launch.searching && launch.match == null));

  Widget _body(PlaybackLaunch launch) {
    if (launch.error != null || _offline(launch)) {
      return LaunchFailure(error: launch.error, offline: _offline(launch));
    }
    if (launch.peer case final peer?) {
      return Text(
        'It’s already on $peer. Playing it from there over your network '
        'skips finding a torrent.',
        style: context.type.bodySmall.copyWith(
          color: context.colors.foregroundSecondary,
        ),
      );
    }
    final resolution = launch.resolution;
    if (resolution == null) {
      return LaunchSearching(searchText: launch.query?.searchText);
    }
    final match = launch.match;
    if (match == null) {
      return SingleChildScrollView(
        child: LaunchMiss(
          resolution: resolution,
          controller: _title,
          onSearch: _search,
        ),
      );
    }
    final all = resolution.candidates;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          resolution.message,
          style: context.type.bodySmall.copyWith(
            color: context.colors.foregroundSecondary,
          ),
        ),
        if (!match.exact) ...[
          const SizedBox(height: Space.s12),
          LaunchNote([
            for (final concern in match.concerns)
              concern.describe(launch.preferences),
            'Play the closest match, or choose another torrent.',
          ]),
        ],
        const SizedBox(height: Space.s12),
        if (_showAll)
          Flexible(
            child: TorrentPicker(
              candidates: all,
              selected: _selected,
              onSelected: (c) => setState(() => _selected = c),
              title: _title,
              onSearch: (_) => _search(),
            ),
          )
        else ...[
          TorrentOption(
            candidate: _selected!,
            best: identical(_selected, all.first),
            selected: true,
            onTap: () {},
          ),
          if (all.length > 1) ...[
            const SizedBox(height: Space.s8),
            Align(
              alignment: Alignment.centerLeft,
              child: SButton.ghost(
                label: 'Show ${all.length - 1} more',
                icon: Icons.expand_more_rounded,
                onPressed: () => setState(() => _showAll = true),
              ),
            ),
          ],
        ],
      ],
    );
    // Large text in a squat window outgrows the dialog; the picker scrolls
    // itself, the single choice scrolls here.
    return _showAll ? body : SingleChildScrollView(child: body);
  }

  SButton? _primary(PlaybackLaunch launch) {
    if (launch.error != null || _offline(launch)) {
      return SButton.primary(
        label: 'Try again',
        icon: Icons.refresh,
        onPressed: _launch.retry,
      );
    }
    if (launch.searching) return null;
    final seconds =
        (_countdown.duration!.inMilliseconds * (1 - _countdown.value) / 1000)
            .ceil();
    final label = _counting ? 'Play in ${seconds}s' : 'Play';
    if (launch.peer != null) {
      return SButton.primary(
        label: label,
        icon: Icons.play_arrow_rounded,
        onPressed: _launch.playFromPeer,
      );
    }
    if (launch.match == null) {
      return SButton.primary(
        label: 'Search',
        icon: Icons.search,
        onPressed: _search,
      );
    }
    return SButton.primary(
      label: label,
      icon: Icons.play_arrow_rounded,
      onPressed: _selected == null ? null : _play,
    );
  }

  void _search() => _launch.retry(title: _title.text);

  String _heading(PlaybackLaunch launch) {
    if (_offline(launch)) return 'You’re offline';
    if (launch.error != null) return 'Couldn’t prepare playback';
    if (launch.peer case final peer?) return 'Play from $peer?';
    if (launch.searching) return 'Finding a torrent';
    final match = launch.match;
    if (match == null) return 'Couldn’t find a torrent';
    return match.exact ? 'Ready to play' : 'Closest match';
  }

  String _subject(PlaybackLaunch launch) {
    final item = launch.item;
    if (item == null) return launch.request.subject.title;
    final series = item.series;
    if (series == null) {
      final year = item.title.releaseYear;
      return year == null ? item.name : '${item.name} · $year';
    }
    return '${series.title} · ${episodeCode(item.season, item.episode)} · '
        '${item.name}';
  }
}
