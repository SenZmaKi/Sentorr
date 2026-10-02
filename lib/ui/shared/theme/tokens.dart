import 'package:flutter/widgets.dart';

/// Primitive scales from DESIGN.md "Geometry and rhythm".
abstract final class Space {
  static const double s2 = 2; // Optical micro-adjustments only.
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s64 = 64;

  // Exceptional feature openings only, e.g. a hero; never routine lists.
  static const double s96 = 96;
}

abstract final class Radii {
  static const double chip = 6;
  static const double control = 8;
  static const double card = 12;
  static const double panel = 16;
  static const double full = 999;
}

abstract final class Borders {
  static const double edge = 1;
  static const double focus = 2;
}

abstract final class IconSizes {
  static const double metadata = 16;
  static const double control = 20;
  static const double navigation = 24;
}

abstract final class ControlHeights {
  static const double compact = 36;
  static const double standard = 40;
  static const double touch = 48;
}

abstract final class Motion {
  static const Duration press = Duration(milliseconds: 100);
  static const Duration hover = Duration(milliseconds: 150);
  static const Duration panel = Duration(milliseconds: 200);

  /// Content entering view: tiles, rows and spotlight copy.
  static const Duration reveal = Duration(milliseconds: 360);

  /// Media-only: artwork zoom inside a fixed tile frame.
  static const Duration artwork = Duration(milliseconds: 450);

  /// Media-only: crossfade between spotlight titles.
  static const Duration spotlightFade = Duration(milliseconds: 700);

  /// Media-only: how long each spotlight title holds before advancing.
  static const Duration spotlightHold = Duration(seconds: 9);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve change = Curves.easeInOutCubic;
}

abstract final class FontFamilies {
  static const String mono = 'GeistMono';
}

/// Raw shadow layer `(offsetX, offsetY, blur, spread, black opacity)`.
BoxShadow shadowLayer(
  double x,
  double y,
  double blur,
  double spread,
  double opacity,
) => BoxShadow(
  color: Color.fromRGBO(0, 0, 0, opacity),
  offset: Offset(x, y),
  blurRadius: blur,
  spreadRadius: spread,
);
