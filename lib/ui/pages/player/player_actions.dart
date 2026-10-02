import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../player/engine.dart';
import '../../../player/session.dart';
import '../../shared/player_view.dart';
import '../../shared/window_manager.dart';
import 'player_ui.dart';

/// Every viewer command, shared by buttons, shortcuts and gestures so each
/// path behaves and acknowledges the same way.
class PlayerActions {
  PlayerActions({
    required this.engine,
    required this.session,
    required this.ui,
    required this.view,
  });

  static const rates = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  static const seekStep = Duration(seconds: 10);
  static const nudgeStep = Duration(seconds: 5);

  final PlaybackEngine engine;
  final PlayerSessionNotifier session;
  final PlayerUi ui;
  final PlayerViewNotifier view;

  Player get _player => engine.player;

  void togglePlay({bool acknowledge = true}) {
    final playing = _player.state.playing;
    // Replay from the end rather than resuming a finished item.
    if (_player.state.completed) unawaited(engine.seek(Duration.zero));
    unawaited(_player.playOrPause());
    if (acknowledge) {
      ui.flash(
        PlayerFeedback(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
        ),
      );
    }
  }

  void seekBy(Duration delta) {
    unawaited(engine.seekBy(delta));
    final seconds = delta.inSeconds;
    ui.flash(
      PlayerFeedback(
        seconds < 0 ? Icons.fast_rewind_rounded : Icons.fast_forward_rounded,
        label: '${seconds < 0 ? '−' : '+'}${seconds.abs()} s',
        side: seconds < 0 ? -1 : 1,
      ),
    );
  }

  /// Number keys: jump to tenths of the runtime.
  void seekToFraction(double fraction) {
    final duration = _player.state.duration;
    if (duration <= Duration.zero) return;
    unawaited(engine.seek(duration * fraction.clamp(0, 1)));
  }

  /// [volume] is 0–100.
  void setVolume(double volume, {bool acknowledge = false}) {
    unawaited(engine.setVolume(volume));
    if (acknowledge) _flashVolume(volume);
  }

  void nudgeVolume(double delta) {
    final next = (_player.state.volume + delta).clamp(0, 100).toDouble();
    setVolume(next, acknowledge: true);
  }

  void toggleMute() {
    final volume = _player.state.volume;
    if (volume > 0) {
      ui.volumeBeforeMute = volume;
      setVolume(0, acknowledge: true);
    } else {
      setVolume(
        ui.volumeBeforeMute == 0 ? 100 : ui.volumeBeforeMute,
        acknowledge: true,
      );
    }
  }

  void setRate(double rate) {
    unawaited(_player.setRate(rate));
    ui.flash(PlayerFeedback(Icons.speed_rounded, label: rateLabel(rate)));
  }

  void stepRate(int direction) {
    final current = _player.state.rate;
    final i = rates.indexWhere((r) => r >= current - 0.001);
    final next = (i < 0 ? rates.length - 1 : i) + direction;
    setRate(rates[next.clamp(0, rates.length - 1)]);
  }

  /// Captions on with the first real track, or off.
  void toggleSubtitles() {
    final selected = _player.state.track.subtitle;
    final on = selected.id != 'no' && selected.id != 'auto';
    final first = _player.state.tracks.subtitle
        .where((t) => t.id != 'no' && t.id != 'auto')
        .firstOrNull;
    if (!on && first == null) {
      ui.flash(
        PlayerFeedback(
          Icons.closed_caption_disabled_outlined,
          label: 'No captions',
        ),
      );
      return;
    }
    unawaited(_player.setSubtitleTrack(on ? SubtitleTrack.no() : first!));
    ui.flash(
      PlayerFeedback(
        on ? Icons.closed_caption_off_outlined : Icons.closed_caption_rounded,
        label: on ? 'Captions off' : 'Captions on',
      ),
    );
  }

  Future<void> toggleFullscreen() async {
    final window = WindowManager.getInstance();
    await window.toggleFullScreen();
    ui.fullscreen = await window.isFullScreen;
  }

  void next() => session.next();

  /// Restarts the current item when past its opening, else goes back one.
  void previous() {
    if (engine.pastStart || session.queue?.previous == null) {
      unawaited(engine.seek(Duration.zero));
    } else {
      session.previous();
    }
  }

  /// Escape and Back: close a panel, leave full screen, then dock the
  /// player in the corner so the app can be browsed while it plays.
  Future<void> back() async {
    if (ui.panel != PlayerPanel.none) return ui.closePanel();
    if (ui.fullscreen) return toggleFullscreen();
    await minimize();
  }

  /// Docks the player; a full-screen window is restored first, since a
  /// corner card over a full-screen app is not browsing.
  Future<void> minimize() async {
    ui.closePanel();
    if (ui.fullscreen) await toggleFullscreen();
    view.minimize();
  }

  void expand() => view.expand();

  Future<void> popOut() async {
    ui.closePanel();
    if (ui.fullscreen) ui.fullscreen = false;
    await view.popOut();
  }

  Future<void> close() async {
    unawaited(_player.pause());
    if (ui.fullscreen) await toggleFullscreen();
    session.close();
  }

  void _flashVolume(double volume) =>
      ui.flash(PlayerFeedback(volumeIcon(volume), label: '${volume.round()}%'));
}

IconData volumeIcon(double volume) => volume <= 0
    ? Icons.volume_off_rounded
    : volume < 50
    ? Icons.volume_down_rounded
    : Icons.volume_up_rounded;

String rateLabel(double rate) => rate == 1
    ? 'Normal'
    : '${rate.toString().replaceFirst(RegExp(r'\.0$'), '')}×';
