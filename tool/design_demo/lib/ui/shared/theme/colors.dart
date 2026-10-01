import 'package:flutter/material.dart';

/// Semantic color roles. Feature widgets read these, never hex values.
@immutable
class SentorrColors extends ThemeExtension<SentorrColors> {
  const SentorrColors({
    required this.canvas,
    required this.surface,
    required this.surfaceControl,
    required this.surfaceRaised,
    required this.surfaceInset,
    required this.foreground,
    required this.foregroundSecondary,
    required this.foregroundMuted,
    required this.foregroundDisabled,
    required this.borderSubtle,
    required this.borderStrong,
    required this.borderControl,
    required this.action,
    required this.onAction,
    required this.actionHover,
    required this.actionPressed,
    required this.stateHover,
    required this.statePressed,
    required this.selection,
    required this.focus,
    required this.info,
    required this.infoSurface,
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.error,
    required this.errorSurface,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceControl;
  final Color surfaceRaised;
  final Color surfaceInset;
  final Color foreground;
  final Color foregroundSecondary;
  final Color foregroundMuted;
  final Color foregroundDisabled;
  final Color borderSubtle;
  final Color borderStrong;
  final Color borderControl;
  final Color action;
  final Color onAction;
  final Color actionHover;
  final Color actionPressed;
  final Color stateHover;
  final Color statePressed;
  final Color selection;
  final Color focus;
  final Color info;
  final Color infoSurface;
  final Color success;
  final Color successSurface;
  final Color warning;
  final Color warningSurface;
  final Color error;
  final Color errorSurface;

  static const dark = SentorrColors(
    canvas: Color(0xFF0D0D0D),
    surface: Color(0xFF191919),
    surfaceControl: Color(0xFF262626),
    surfaceRaised: Color(0xFF303030),
    surfaceInset: Color(0xFF090909),
    foreground: Color(0xFFFCFDFF),
    foregroundSecondary: Color(0xFFB3B3B3),
    foregroundMuted: Color(0xFFAAAAAA),
    foregroundDisabled: Color(0xFF464A4D),
    borderSubtle: Color(0xFF333333),
    borderStrong: Color(0xFF454545),
    borderControl: Color(0xFFAAAAAA),
    action: Color(0xFFFCFDFF),
    onAction: Color(0xFF000000),
    actionHover: Color(0xFFE5E5E5),
    actionPressed: Color(0xFFD4D4D4),
    stateHover: Color(0xFF333333),
    statePressed: Color(0xFF1F1F1F),
    selection: Color(0xFF262626),
    focus: Color(0xFFFCFDFF),
    info: Color(0xFF3B9EFF),
    infoSurface: Color(0xFF071B30),
    success: Color(0xFF11FF99),
    successSurface: Color(0xFF052619),
    warning: Color(0xFFFFC53D),
    warningSurface: Color(0xFF2A2108),
    error: Color(0xFFFF6B81),
    errorSurface: Color(0xFF300710),
  );

  static const light = SentorrColors(
    canvas: Color(0xFFE7E7E7),
    surface: Color(0xFFF3F3F3),
    surfaceControl: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceInset: Color(0xFFDCDCDC),
    foreground: Color(0xFF171717),
    foregroundSecondary: Color(0xFF4D4D4D),
    foregroundMuted: Color(0xFF606060),
    foregroundDisabled: Color(0xFFA1A1A1),
    borderSubtle: Color(0xFFD4D4D4),
    borderStrong: Color(0xFFB8B8B8),
    borderControl: Color(0xFF707070),
    action: Color(0xFF171717),
    onAction: Color(0xFFFFFFFF),
    actionHover: Color(0xFF333333),
    actionPressed: Color(0xFF000000),
    stateHover: Color(0xFFF5F5F5),
    statePressed: Color(0xFFE5E5E5),
    selection: Color(0xFFEBEBEB),
    focus: Color(0xFF171717),
    info: Color(0xFF0761D1),
    infoSurface: Color(0xFFEAF3FF),
    success: Color(0xFF067647),
    successSurface: Color(0xFFECFDF3),
    warning: Color(0xFF854A0E),
    warningSurface: Color(0xFFFFFAEB),
    error: Color(0xFFC50000),
    errorSurface: Color(0xFFFFF1F2),
  );

  @override
  SentorrColors copyWith() => this;

  @override
  SentorrColors lerp(SentorrColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SentorrColors(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      surfaceControl: l(surfaceControl, other.surfaceControl),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceInset: l(surfaceInset, other.surfaceInset),
      foreground: l(foreground, other.foreground),
      foregroundSecondary: l(foregroundSecondary, other.foregroundSecondary),
      foregroundMuted: l(foregroundMuted, other.foregroundMuted),
      foregroundDisabled: l(foregroundDisabled, other.foregroundDisabled),
      borderSubtle: l(borderSubtle, other.borderSubtle),
      borderStrong: l(borderStrong, other.borderStrong),
      borderControl: l(borderControl, other.borderControl),
      action: l(action, other.action),
      onAction: l(onAction, other.onAction),
      actionHover: l(actionHover, other.actionHover),
      actionPressed: l(actionPressed, other.actionPressed),
      stateHover: l(stateHover, other.stateHover),
      statePressed: l(statePressed, other.statePressed),
      selection: l(selection, other.selection),
      focus: l(focus, other.focus),
      info: l(info, other.info),
      infoSurface: l(infoSurface, other.infoSurface),
      success: l(success, other.success),
      successSurface: l(successSurface, other.successSurface),
      warning: l(warning, other.warning),
      warningSurface: l(warningSurface, other.warningSurface),
      error: l(error, other.error),
      errorSurface: l(errorSurface, other.errorSurface),
    );
  }
}

/// Playback/image-overlay context, independent of app brightness.
abstract final class OverlayColors {
  static const foreground = Color(0xFFFFFFFF);
  static const foregroundSecondary = Color(0xFFD4D4D4);
  static const controlSurface = Color(0xCC000000); // black 80%
  static const scrim = Color(0x99000000); // black 60%
  static const focus = Color(0xFFFFFFFF);
  static const inactiveTrack = Color(0xFF888888);
  static const artworkFade = [Color(0x00000000), Color(0xCC000000)];
}
