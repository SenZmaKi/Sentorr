import 'package:flutter/material.dart';

/// Theme-owned brand assets. Packaged desktop launchers always use the dark
/// artwork; Android swaps its launcher alias.
class SentorrBrand extends ThemeExtension<SentorrBrand> {
  const SentorrBrand(this.variant);

  final String variant;
  static const dark = SentorrBrand('dark');
  static const light = SentorrBrand('light');

  String get logo => variant == 'light'
      ? 'assets/images/sentorr-icon-light.png'
      : 'assets/images/sentorr-icon.png';
  String get tray => 'assets/images/tray-$variant.png';
  String get dock => 'assets/images/dock-$variant.png';
  String get window => 'assets/images/window-$variant.ico';

  @override
  SentorrBrand copyWith({String? variant}) =>
      SentorrBrand(variant ?? this.variant);

  @override
  SentorrBrand lerp(covariant SentorrBrand? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
