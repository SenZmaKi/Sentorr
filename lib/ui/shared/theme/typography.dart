import 'package:flutter/material.dart';

import 'tokens.dart';

enum TextRole {
  display,
  headline,
  title,
  subtitle,
  bodyLarge,
  body,
  bodySmall,
  label,
  caption,
}

/// A sans family plus the tracking its letterforms need at each role.
/// Tracking is tuned per face, so switching faces swaps both together.
class TypeFace {
  const TypeFace({
    required this.text,
    required this.headings,
    required this.tracking,
  });

  final String text;

  /// Display, headline and title.
  final String headings;
  final Map<TextRole, double> tracking;

  // Inter Display is already tight, so headings need little negative
  // tracking; text sizes follow Inter's size-specific spacing (~-0.01em).
  static const inter = TypeFace(
    text: 'Inter',
    headings: 'InterDisplay',
    tracking: {
      TextRole.display: -1.0,
      TextRole.headline: -0.5,
      TextRole.title: -0.2,
      TextRole.subtitle: -0.35,
      TextRole.bodyLarge: -0.25,
      TextRole.body: -0.18,
      TextRole.bodySmall: -0.08,
      TextRole.label: -0.08,
      TextRole.caption: 0,
    },
  );

  // Barlow is a compact DIN-style grotesk: headings tighten slightly, and
  // small sizes open up a touch so narrow letters stay legible.
  static const barlow = TypeFace(
    text: 'Barlow',
    headings: 'Barlow',
    tracking: {
      TextRole.display: -0.6,
      TextRole.headline: -0.3,
      TextRole.title: -0.1,
      TextRole.subtitle: 0,
      TextRole.bodyLarge: 0,
      TextRole.body: 0.05,
      TextRole.bodySmall: 0.1,
      TextRole.label: 0.1,
      TextRole.caption: 0.2,
    },
  );
}

/// Named text roles from DESIGN.md "Typography", uncolored.
@immutable
class SentorrType extends ThemeExtension<SentorrType> {
  const SentorrType._();

  static const instance = SentorrType._();

  /// The active face. Barlow is on trial; Inter remains bundled.
  static const face = TypeFace.barlow;

  TextStyle _role(TextRole role, double size, double line, FontWeight w) =>
      TextStyle(
        fontFamily: switch (role) {
          TextRole.display ||
          TextRole.headline ||
          TextRole.title => face.headings,
          _ => face.text,
        },
        fontSize: size,
        height: line / size,
        fontWeight: w,
        letterSpacing: face.tracking[role],
      );

  TextStyle get display => _role(TextRole.display, 48, 56, FontWeight.w600);
  TextStyle get headline => _role(TextRole.headline, 32, 40, FontWeight.w600);
  TextStyle get title => _role(TextRole.title, 24, 32, FontWeight.w600);
  TextStyle get subtitle => _role(TextRole.subtitle, 20, 28, FontWeight.w600);
  TextStyle get bodyLarge => _role(TextRole.bodyLarge, 18, 28, FontWeight.w400);
  TextStyle get body => _role(TextRole.body, 16, 24, FontWeight.w400);
  TextStyle get bodySmall => _role(TextRole.bodySmall, 14, 20, FontWeight.w400);
  TextStyle get label => _role(TextRole.label, 14, 20, FontWeight.w500);
  TextStyle get caption => _role(TextRole.caption, 12, 16, FontWeight.w400);
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
