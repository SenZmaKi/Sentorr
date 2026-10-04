import 'package:flutter/widgets.dart';

import '../../components/player_control.dart';
import '../../shared/layout/adaptive.dart';
import '../../shared/theme/theme.dart';

/// The shapes the full player takes, from its own size (it is the window
/// when full) and the input mode:
/// - [compact]: a phone held upright; panels rise as bottom sheets.
/// - [short]: a phone on its side or a squat window; chrome slims and
///   panels become full-height side sheets.
/// - [regular]: tablets and desktop windows; panels float over the corner.
/// - [wide]: large monitors (≥ 1440); panels dock beside the picture.
enum PlayerShape { compact, short, regular, wide }

/// Where an open panel (settings, episodes, torrents) sits.
enum PanelPlacement {
  /// Full width along the bottom edge, up to most of the height.
  bottomSheet,

  /// Full height along the trailing edge.
  sideSheet,

  /// A floating card above the bar's trailing end.
  floating,

  /// Full height beside the picture, which shrinks to make room, so the
  /// panel never covers what is playing. Wide players only.
  docked,
}

/// Everything about the player's chrome that depends on its size, so no
/// bar or panel compares raw widths itself.
@immutable
class PlayerLayout {
  PlayerLayout(Size size, this.input)
    : size = LayoutSize(size),
      shape = _shapeOf(LayoutSize(size));

  final LayoutSize size;
  final InputMode input;
  final PlayerShape shape;

  static PlayerShape _shapeOf(LayoutSize s) => s.compact
      ? PlayerShape.compact
      : s.short
      ? PlayerShape.short
      : s.large
      ? PlayerShape.wide
      : PlayerShape.regular;

  bool get compact => shape == PlayerShape.compact;
  bool get short => shape == PlayerShape.short;
  bool get wide => shape == PlayerShape.wide;

  /// Phones: bars inset less, panels become sheets, Up next stays hidden.
  bool get handheld => compact || short;

  PanelPlacement get panels => switch (shape) {
    PlayerShape.compact => PanelPlacement.bottomSheet,
    PlayerShape.short => PanelPlacement.sideSheet,
    PlayerShape.regular => PanelPlacement.floating,
    PlayerShape.wide => PanelPlacement.docked,
  };

  /// Sheets cover the bars' controls, so bars step aside while one is open.
  bool get barsYieldToPanels =>
      panels == PanelPlacement.bottomSheet ||
      panels == PanelPlacement.sideSheet;

  /// Glyph size in the player's controls; their targets stay 48.
  double get icon => handheld ? PlayerMetrics.iconHandheld : PlayerMetrics.icon;

  /// Horizontal inset of the bottom bar's content.
  double get barInset => handheld ? Space.s8 : Space.s16;

  /// Room for the bars' scrim to fade to clear before their content; short
  /// windows keep it slim so the picture keeps the height.
  double get topFade => short ? Space.s16 : Space.s48;
  double get bottomFade => short ? Space.s24 : Space.s64;

  /// Volume is a hover slider; touch devices have hardware keys for it.
  bool get showVolume => input.canHover;

  /// The live torrent's stats in the top bar: none on a phone held upright
  /// (the title needs the room), the short form below expanded.
  bool get showStats => !compact;
  bool get compactStats => !size.expanded;

  /// The near-end Up next card floats over the picture's corner; phones
  /// have no corner to spare, and the end screen offers next instead.
  bool get showUpNextCard => !handheld;

  /// Space the bottom bar occupies; floating panels and cards sit above.
  double barClearance({required bool floatingBars}) =>
      (floatingBars ? 124 : 96) - (short ? Space.s40 : 0);

  /// Space a floating top bar occupies.
  double topClearance({required bool floatingBars}) =>
      floatingBars ? 100 : Space.s16;

  /// A panel's width in a slot [available] wide. Sheets along the bottom
  /// take the full width; side sheets and floating cards keep [preferred],
  /// side sheets leaving at least a third of the picture visible.
  double panelWidth(double preferred, double available) => switch (panels) {
    PanelPlacement.bottomSheet => available,
    PanelPlacement.sideSheet => preferred.clamp(0, available * 2 / 3),
    PanelPlacement.floating ||
    PanelPlacement.docked => preferred.clamp(0, available),
  };

  @override
  bool operator ==(Object other) =>
      other is PlayerLayout &&
      other.size == size &&
      other.input == input &&
      other.shape == shape;

  @override
  int get hashCode => Object.hash(size, input, shape);
}

/// Hands the player's [PlayerLayout] to its chrome, derived from the
/// player's own constraints.
class PlayerLayoutScope extends StatelessWidget {
  const PlayerLayoutScope({super.key, required this.child});

  final Widget child;

  static PlayerLayout of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Scope>()?.layout ??
      PlayerLayout(MediaQuery.sizeOf(context), context.input);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final layout = PlayerLayout(box.biggest, context.input);
      return _Scope(
        layout: layout,
        child: PlayerIconSize(size: layout.icon, child: child),
      );
    },
  );
}

class _Scope extends InheritedWidget {
  const _Scope({required this.layout, required super.child});

  final PlayerLayout layout;

  @override
  bool updateShouldNotify(_Scope old) => old.layout != layout;
}

extension PlayerLayoutContext on BuildContext {
  PlayerLayout get playerLayout => PlayerLayoutScope.of(this);
}

/// Which corner the docked player snaps to.
enum DockCorner {
  topLeft(left: true, top: true),
  topRight(left: false, top: true),
  bottomLeft(left: true, top: false),
  bottomRight(left: false, top: false);

  const DockCorner({required this.left, required this.top});

  static DockCorner of({required bool left, required bool top}) =>
      values.firstWhere((c) => c.left == left && c.top == top);

  final bool left;
  final bool top;
}

/// Where the docked player sits in a window of [size]: in [corner], clear
/// of the bottom navigation ([navExtent], measured) and of the system
/// [insets]. Phones get a smaller card, and a short window caps
/// it by height so it covers as little of the page as it can.
Rect dockedPlayerRect(
  Size size,
  EdgeInsets insets,
  double navExtent, {
  DockCorner corner = DockCorner.bottomRight,
}) {
  final screen = LayoutSize(size);
  final handheld = screen.compact || screen.short;
  final width = screen.compact
      ? (size.width * 0.45).clamp(_minHandheld, 260.0)
      : screen.short
      ? (size.height * 0.3 * 16 / 9).clamp(_minHandheld, 260.0)
      : (size.width * 0.28).clamp(260.0, 420.0);
  final height = width * 9 / 16;
  final margin = handheld ? Space.s12 : Space.s24;
  final bottom = margin + (navExtent > 0 ? navExtent : insets.bottom);
  return Rect.fromLTWH(
    corner.left
        ? margin + insets.left
        : size.width - width - margin - insets.right,
    corner.top ? margin + insets.top : size.height - height - bottom,
    width,
    height,
  );
}

/// Smallest docked card a phone gets: still a recognisable picture.
const _minHandheld = 160.0;
