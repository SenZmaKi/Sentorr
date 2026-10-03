import 'package:flutter/material.dart';

import 'tokens.dart';

TextStyle _sans(double size, double line, FontWeight weight, double tracking) =>
    TextStyle(
      fontFamily: FontFamilies.sans,
      fontSize: size,
      height: line / size,
      fontWeight: weight,
      letterSpacing: tracking,
    );

/// Named text roles from DESIGN.md "Typography", uncolored.
@immutable
class SentorrType extends ThemeExtension<SentorrType> {
  const SentorrType._();

  static const instance = SentorrType._();

  TextStyle get display => _sans(48, 56, FontWeight.w600, -1.5);
  TextStyle get headline => _sans(32, 40, FontWeight.w600, -0.8);
  TextStyle get title => _sans(24, 32, FontWeight.w600, -0.4);
  TextStyle get subtitle => _sans(20, 28, FontWeight.w600, -0.3);
  TextStyle get bodyLarge => _sans(18, 28, FontWeight.w400, 0);
  TextStyle get body => _sans(16, 24, FontWeight.w400, 0);
  TextStyle get bodySmall => _sans(14, 20, FontWeight.w400, 0);
  TextStyle get label => _sans(14, 20, FontWeight.w500, 0);
  TextStyle get caption => _sans(12, 16, FontWeight.w400, 0);
  TextStyle get technical => const TextStyle(
    fontFamily: FontFamilies.mono,
    fontSize: 13,
    height: 20 / 13,
    fontWeight: FontWeight.w400,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  TextTheme toTextTheme(Color color) => TextTheme(
    displayLarge: display,
    headlineMedium: headline,
    titleLarge: title,
    titleMedium: subtitle,
    bodyLarge: bodyLarge,
    bodyMedium: body,
    bodySmall: bodySmall,
    labelLarge: label,
    labelSmall: caption,
  ).apply(bodyColor: color, displayColor: color);

  @override
  SentorrType copyWith() => this;

  @override
  SentorrType lerp(SentorrType? other, double t) => this;
}
