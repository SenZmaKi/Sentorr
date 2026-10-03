import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../player/engine.dart';
import '../../../player/focus_playback.dart';
import '../../../settings/notifier.dart';
import '../../../player/queue_builder.dart';
import '../../../player/session.dart';
import '../../../player/sleep_timer.dart';
import '../../../player/stream/torrent_playback.dart';
import '../../../shared/app_lifecycle.dart';
import '../../shared/player_view.dart';
import 'captions_view.dart';
import 'center_feedback.dart';
import 'end_screen.dart';
import 'mini_chrome.dart';
import 'player_actions.dart';
import 'player_chrome.dart';
import 'player_dock.dart';
import 'player_input.dart';
import 'player_layout.dart';
import 'player_panels.dart';
import 'player_ui.dart';
import 'player_value.dart';
import 'stage_states.dart';
import 'nerd_stats.dart';
import 'switching_prompt.dart';
import 'torrent_stats.dart';

/// The full-window player: picture, captions and feedback beneath chrome
/// that hides while watching, with the end screen and failures on top.
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  final _ui = PlayerUi();
  final _focus = FocusNode(debugLabel: 'Player');
  final _subscriptions = <StreamSubscription<Object?>>[];
  late final PlaybackEngine _engine = ref.read(playbackEngineProvider);
  late final _actions = PlayerActions(
    engine: _engine,
    session: ref.read(playerSessionProvider.notifier),
    ui: _ui,
    view: ref.read(playerViewProvider.notifier),
  );

  late final _focusPlayback = FocusPlayback(
    isPlaying: () => _engine.state.playing,
    pause: _engine.player.pause,
    play: _engine.player.play,
  );

  /// Kept so the page can finish fading out after the session closes.
  PlayerSession? _session;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _session = ref.read(playerSessionProvider);
    final s = _engine.stream;
    _subscriptions.addAll([
      s.playing.listen((playing) => _ui.playing = playing),
      s.completed.listen(_onCompleted),
      s.error.listen((_) {
        // Only failures that leave nothing playing are the viewer's
        // problem; the torrent behind it counts as failed.
        if (_engine.state.duration == Duration.zero) {
          _engine.streaming.unplayable();
        }
      }),
    ]);
    _ui.wake();
  }

  void _onCompleted(bool completed) {
    if (!mounted) return;
    if (!completed) {
      if (_ended) setState(() => _ended = false);
      return;
    }
    final claimed = ref.read(sleepTimerProvider.notifier).consumeEndOfItem();
    final hasNext = ref.read(playerSessionProvider)?.queue?.next != null;
    // The Up next card already counted down the closing seconds, so the
    // next item simply starts. The end screen is only for when the viewer
    // waved the card away, the sleep timer claimed the ending, or nothing
    // follows.
    if (!claimed && hasNext && !_ui.upNextDismissed) {
      _actions.next();
      return;
    }
    setState(() => _ended = true);
  }

  void _replay() {
    setState(() => _ended = false);
    unawaited(_engine.seek(Duration.zero));
    unawaited(_engine.player.play());
  }

  @override
  void dispose() {
    _focusPlayback.dispose();
    for (final s in _subscriptions) {
      s.cancel();
    }
    _focus.dispose();
    _ui.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the engine alive for as long as the page is mounted.
    ref.watch(playbackEngineProvider);
    ref.listen(playerSessionProvider.select((s) => s?.current?.id), (_, id) {
      if (id == null) return;
      setState(() => _ended = false);
      _ui.itemChanged();
    });
    ref.listen(playerViewProvider, (_, view) {
      // Keys belong to the player again once it fills the app.
      if (view != PlayerView.mini) {
        // ExcludeFocus must rebuild before this node can accept focus.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ref.read(playerViewProvider) != PlayerView.mini) {
            _focus.requestFocus();
          }
        });
      }
    });
    ref.listen(AppLifecycleNotifier.provider, (_, lifecycle) {
      unawaited(
        _focusPlayback.change(
          lifecycle,
          enabled:
              ref.read(settingsProvider).streaming.pauseOnFocusLoss &&
              ref.read(playerViewProvider) != PlayerView.popOut,
        ),
      );
    });
    final view = ref.watch(playerViewProvider);
    final full = view == PlayerView.full;
    final session = _session = ref.watch(playerSessionProvider) ?? _session;
    if (session == null) return const ColoredBox(color: Colors.black);
    final queue = session.queue;
    final next = queue?.next;
    final p = _engine.player;

    final video = Video(
      controller: _engine.video,
      controls: NoVideoControls,
      // Sentorr owns focus pausing, including inactive and pop-out behavior.
      pauseUponEnteringBackgroundMode: false,
      resumeUponEnteringForegroundMode: false,
      fill: Colors.black,
      subtitleViewConfiguration: const SubtitleViewConfiguration(
        visible: false,
      ),
    );
    return PopScope(
      // Docked, Back belongs to the app beneath.
      canPop: view == PlayerView.mini,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_actions.back());
      },
      child: PlayerUiScope(
        ui: _ui,
        child: PlayerLayoutScope(
          child: ExcludeFocus(
            excluding: view == PlayerView.mini,
            child: PlayerShortcuts(
              actions: _actions,
              focusNode: _focus,
              child: ColoredBox(
                color: Colors.black,
                // Wide players dock the open panel beside the picture.
                child: ListenableBuilder(
                  listenable: _ui,
                  builder: (context, stage) => PlayerDock(
                    panel: full
                        ? openPlayerPanel(
                            ui: _ui,
                            session: session,
                            engine: _engine,
                            actions: _actions,
                          )
                        : null,
                    child: stage!,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (full)
                        StageGestures(actions: _actions, child: video)
                      else
                        video,
                      if (view != PlayerView.mini)
                        ListenableBuilder(
                          listenable: _ui,
                          builder: (context, _) => CaptionsView(
                            player: p,
                            lifted: _ui.controlsVisible,
                          ),
                        ),
                      PlayerValue(
                        stream: p.stream.buffering,
                        initial: p.state.buffering,
                        builder: (context, buffering) => PlayerValue(
                          stream: p.stream.playing,
                          initial: p.state.playing,
                          builder: (context, playing) => BufferingIndicator(
                            buffering: buffering && !_ended,
                            playing: playing,
                          ),
                        ),
                      ),
                      if (full) const CenterFeedback(),
                      ValueListenableBuilder(
                        valueListenable: _engine.streaming.status,
                        builder: (context, stream, _) => PlayerValue(
                          stream: p.stream.duration,
                          initial: p.state.duration,
                          builder: (context, duration) => AnimatedSwitcher(
                            duration: const Duration(milliseconds: 450),
                            child:
                                duration == Duration.zero &&
                                    stream?.stage != StreamStage.failed
                                ? IgnorePointer(
                                    child: OpeningCover(
                                      subject:
                                          session.current?.title ??
                                          session.request.subject,
                                      label: !full
                                          ? ''
                                          : queue == null &&
                                                session.error == null
                                          ? _resolvingLabel(session.request)
                                          : streamLabel(stream),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      if (!full)
                        MiniChrome(
                          player: p,
                          actions: _actions,
                          item: session.current,
                          hasNext: next != null,
                          poppedOut: view == PlayerView.popOut,
                        ),
                      if (_ended && full)
                        EndScreen(
                          key: ValueKey(session.current?.id),
                          next: next,
                          onPlayNext: _actions.next,
                          onReplay: _replay,
                          onBack: _actions.close,
                        ),
                      // Above the end screen, as on YouTube: scrub back or leave.
                      if (full)
                        PlayerChrome(
                          session: session,
                          engine: _engine,
                          actions: _actions,
                          ended: _ended,
                        ),
                      if (full)
                        ListenableBuilder(
                          listenable: _ui,
                          builder: (context, _) => _ui.statsVisible
                              ? NerdStats(
                                  engine: _engine,
                                  onClose: _ui.toggleStats,
                                )
                              : const SizedBox.shrink(),
                        ),
                      if (full)
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            _ui,
                            _engine.streaming.status,
                          ]),
                          builder: (context, _) =>
                              _failure(session, _engine.streaming.status.value),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _retry() => ref.read(playerSessionProvider.notifier).retry();

  /// A torrent that failed to start, or nothing left to try. Yields to the
  /// torrent picker, which is how the viewer answers it.
  Widget _failure(PlayerSession session, StreamStatus? stream) {
    if (_ui.panel == PlayerPanel.torrents) return const SizedBox.shrink();
    final streaming = _engine.streaming;
    if (stream?.stage == StreamStage.switching) {
      return SwitchingPrompt(
        status: stream!,
        onChoose: _actions.chooseTorrent,
        onNow: streaming.switchNow,
      );
    }
    final message = _problem(session, stream);
    if (message == null) return const SizedBox.shrink();
    final queue = session.queue;
    final next = queue?.next;
    final others = (stream?.options?.candidates.length ?? 0) > 1;
    return PlaybackProblem(
      message: message,
      onBack: _actions.close,
      onSkip: next == null ? null : _actions.next,
      onChoose: queue == null ? null : _actions.chooseTorrent,
      chooseLabel: others ? 'Choose another torrent' : 'Search for torrents',
      onRetry: queue == null
          ? _retry
          : () => unawaited(_engine.reopen(session.current!)),
    );
  }

  String? _problem(PlayerSession session, StreamStatus? stream) {
    if (session.queue == null && session.error != null) {
      return "Couldn't find what to play for ${session.request.subject.title}. "
          'Check your connection and try again.';
    }
    if (stream?.stage != StreamStage.failed) return null;
    final tried = stream!.failed.length;
    return tried > 1
        ? '${stream.problem} $tried torrents couldn’t start. Choose another '
              'or try again.'
        : '${stream.problem} Try again or choose another torrent.';
  }

  String _resolvingLabel(PlayRequest request) => switch (request) {
    PlayTitle(:final title) => 'Finding the first episode of ${title.title}',
    PlayEpisode() => 'Starting ${request.subject.title}',
  };
}
