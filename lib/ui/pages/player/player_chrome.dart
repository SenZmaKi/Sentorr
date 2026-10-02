import 'package:flutter/material.dart';

import '../../../player/engine.dart';
import '../../../player/session.dart';
import '../../components/motion.dart';
import '../../components/surface.dart';
import '../../shared/theme/theme.dart';
import 'bottom_bar.dart';
import 'player_actions.dart';
import 'player_ui.dart';
import 'player_value.dart';
import 'episodes_panel.dart';
import 'settings_menu.dart';
import 'top_bar.dart';
import 'up_next_card.dart';

/// Everything drawn over the picture that comes and goes with activity:
/// scrims, top and bottom bars, floating panels and the Up next card.
class PlayerChrome extends StatelessWidget {
  const PlayerChrome({
    super.key,
    required this.session,
    required this.engine,
    required this.actions,
    required this.ended,
  });

  /// Space the bottom bar occupies; panels and cards float above it.
  static double barClearance(BuildContext context) =>
      context.player.floatingBars ? 124 : 96;

  /// Space the top bar occupies, when it is a floating surface.
  static double topClearance(BuildContext context) =>
      context.player.floatingBars ? 100 : Space.s16;

  final PlayerSession session;
  final PlaybackEngine engine;
  final PlayerActions actions;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final ui = PlayerUiScope.of(context);
    final visible = ui.controlsVisible;
    final queue = session.queue;
    final duration = reduceMotion(context) ? Duration.zero : Motion.panel;
    final compact = MediaQuery.sizeOf(context).width < 600;
    Widget fade(Widget child) => IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        curve: Motion.change,
        child: child,
      ),
    );

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: fade(
            _BarBackdrop(
              top: true,
              child: TopBar(
                item: session.current,
                fallbackTitle: session.request.subject.title,
                onBack: actions.minimize,
                onClose: actions.close,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: fade(
            _BarBackdrop(
              top: false,
              child: BottomBar(
                player: engine.player,
                actions: actions,
                queue: queue,
              ),
            ),
          ),
        ),
        // Yields to an open panel, which occupies the same corner.
        if (queue?.next != null &&
            !ended &&
            !compact &&
            ui.panel == PlayerPanel.none)
          _UpNextSlot(engine: engine, session: session, actions: actions),
        Positioned(
          right: Space.s16,
          bottom: barClearance(context),
          top: topClearance(context),
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: Motion.enter,
              switchOutCurve: Motion.change,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.bottomRight,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: switch (ui.panel) {
                PlayerPanel.settings => SettingsMenu(
                  key: const ValueKey('settings'),
                  player: engine.player,
                  actions: actions,
                ),
                PlayerPanel.queue when queue != null => EpisodesPanel(
                  key: const ValueKey('queue'),
                  queue: queue,
                  onJump: actions.session.jump,
                  onClose: ui.closePanel,
                ),
                _ => const SizedBox.shrink(key: ValueKey('none')),
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// What a bar sits on. Dark: a fade over the picture, edge to edge. Light:
/// a floating light surface inset from the edges, so dark controls stay
/// legible over any picture.
class _BarBackdrop extends StatelessWidget {
  const _BarBackdrop({required this.top, required this.child});

  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.player;
    if (colors.floatingBars) {
      return SafeArea(
        top: top,
        bottom: !top,
        child: Padding(
          padding: const EdgeInsets.all(Space.s12),
          child: DepthBox(
            style: context.depth.of(SurfaceDepth.floating),
            radius: Radii.panel,
            border: Border.all(color: context.colors.borderStrong),
            padding: EdgeInsets.only(top: top ? 0 : Space.s8),
            child: child,
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.bottomCenter : Alignment.topCenter,
          end: top ? Alignment.topCenter : Alignment.bottomCenter,
          colors: top
              ? [colors.scrim.withValues(alpha: 0), colors.scrim]
              : colors.artworkFade,
        ),
      ),
      child: SafeArea(
        top: top,
        bottom: !top,
        child: Padding(
          // Room for the fade to reach clear before the bar's content.
          padding: top
              ? const EdgeInsets.only(bottom: Space.s48)
              : const EdgeInsets.only(top: Space.s64),
          child: child,
        ),
      ),
    );
  }
}

/// Shows [UpNextCard] over the closing seconds unless dismissed.
class _UpNextSlot extends StatelessWidget {
  const _UpNextSlot({
    required this.engine,
    required this.session,
    required this.actions,
  });

  final PlaybackEngine engine;
  final PlayerSession session;
  final PlayerActions actions;

  // Long items have credits worth skipping; short ones only a moment.
  static Duration _lead(Duration total) => total > const Duration(minutes: 10)
      ? const Duration(seconds: 30)
      : const Duration(seconds: 12);

  @override
  Widget build(BuildContext context) {
    final ui = PlayerUiScope.of(context);
    final next = session.queue!.next!;
    final p = engine.player;
    // Fixed above the bar whether or not it shows: a card that moves with
    // the chrome would drag its hover preview along.
    return Positioned(
      right: Space.s24,
      bottom: PlayerChrome.barClearance(context),
      child: PlayerValue(
        stream: p.stream.duration,
        initial: p.state.duration,
        builder: (context, total) => PlayerValue(
          stream: p.stream.position,
          initial: p.state.position,
          builder: (context, position) {
            final remaining = total - position;
            final show =
                total > Duration.zero &&
                !ui.upNextDismissed &&
                remaining <= _lead(total) &&
                remaining > Duration.zero;
            return AnimatedSwitcher(
              duration: reduceMotion(context) ? Duration.zero : Motion.reveal,
              switchInCurve: Motion.enter,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(a),
                  child: child,
                ),
              ),
              child: show
                  ? UpNextCard(
                      key: ValueKey(next.id),
                      item: next,
                      remaining: remaining,
                      onPlay: actions.next,
                      onDismiss: ui.dismissUpNext,
                      onDock: actions.minimize,
                    )
                  : const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
