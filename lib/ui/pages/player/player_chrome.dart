import 'package:flutter/material.dart';

import '../../../player/engine.dart';
import '../../../player/session.dart';
import '../../components/motion.dart';
import '../../components/surface.dart';
import '../../shared/theme/theme.dart';
import 'bottom_bar.dart';
import 'bar_visibility.dart';
import 'player_actions.dart';
import 'player_ui.dart';
import 'player_value.dart';
import 'top_bar.dart';
import 'panel_slot.dart';
import 'player_panels.dart';
import 'player_layout.dart';
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

  final PlayerSession session;
  final PlaybackEngine engine;
  final PlayerActions actions;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final ui = PlayerUiScope.of(context);
    final layout = context.playerLayout;
    // Sheets cover the bars' controls; the bars step aside while one shows.
    final visible =
        ui.controlsVisible &&
        !(layout.barsYieldToPanels &&
            ui.panel != PlayerPanel.none &&
            !ui.settingsPopup);
    final queue = session.queue;
    final duration = reduceMotion(context) ? Duration.zero : Motion.panel;
    Widget fade(Widget child) =>
        BarVisibility(visible: visible, duration: duration, child: child);

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
                stream: engine.streaming.status,
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
            layout.showUpNextCard &&
            ui.panel == PlayerPanel.none)
          _UpNextSlot(engine: engine, session: session, actions: actions),
        PanelSlot(
          popup: ui.settingsPopup,
          floatingBars: context.player.floatingBars,
          panel: openPlayerPanel(
            ui: ui,
            session: session,
            engine: engine,
            actions: actions,
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
    final layout = context.playerLayout;
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
              ? EdgeInsets.only(bottom: layout.topFade)
              : EdgeInsets.only(top: layout.bottomFade),
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
      // Clear of a landscape phone's cut-out on that side.
      right: Space.s24 + MediaQuery.paddingOf(context).right,
      bottom: context.playerLayout.barClearance(
        floatingBars: context.player.floatingBars,
      ),
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
