import 'package:flutter/material.dart';

import 'colors.dart';
import 'depth.dart';
import 'typography.dart';
import 'tokens.dart';

export 'colors.dart';
export 'depth.dart';
export 'tokens.dart';
export 'typography.dart';

ThemeData buildSentorrTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? SentorrColors.dark : SentorrColors.light;
  final type = SentorrType.instance;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.action,
    onPrimary: c.onAction,
    secondary: c.surfaceControl,
    onSecondary: c.foreground,
    surface: c.surface,
    onSurface: c.foreground,
    onSurfaceVariant: c.foregroundSecondary,
    error: c.error,
    onError: c.onAction,
    outline: c.borderControl,
    outlineVariant: c.borderSubtle,
    // Automatic Material surface tint is disabled per the depth contract.
    surfaceTint: Colors.transparent,
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: FontFamilies.sans,
    scaffoldBackgroundColor: c.canvas,
    textTheme: type.toTextTheme(c.foreground),
    splashFactory: NoSplash.splashFactory,
    hoverColor: c.stateHover,
    highlightColor: c.statePressed,
    focusColor: Colors.transparent,
    dividerTheme: DividerThemeData(color: c.borderSubtle, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: c.borderStrong),
      ),
      textStyle: type.caption.copyWith(color: c.foreground),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: c.action,
      inactiveTrackColor: c.surfaceInset,
      thumbColor: c.action,
      overlayColor: c.stateHover.withValues(alpha: 0.5),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 1),
    ),
    extensions: [c, SentorrDepth.resolve(c, brightness), type],
  );
}

extension SentorrThemeContext on BuildContext {
  SentorrColors get colors => Theme.of(this).extension<SentorrColors>()!;
  SentorrDepth get depth => Theme.of(this).extension<SentorrDepth>()!;
  SentorrType get type => Theme.of(this).extension<SentorrType>()!;
}

/// Explicit presentation context for controls placed over artwork or video:
/// resolves the dark roles regardless of app brightness, so feature widgets
/// never branch on brightness themselves.
class ImageOverlayContext extends StatelessWidget {
  const ImageOverlayContext({super.key, required this.child});

  final Widget child;

  static final _theme = buildSentorrTheme(Brightness.dark);

  @override
  Widget build(BuildContext context) => Theme(data: _theme, child: child);
}
