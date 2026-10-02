import 'package:flutter/material.dart';

/// The player's own colour scheme, in both brightnesses. Dark puts white
/// controls on scrims over the picture; light lifts the bars onto floating
/// light surfaces with dark controls, so the player matches the app in
/// either mode. Captions are the exception: they always use [OverlayColors]
/// because they are read against the picture.
@immutable
class PlayerColors extends ThemeExtension<PlayerColors> {
  const PlayerColors({
    required this.foreground,
    required this.foregroundSecondary,
    required this.foregroundMuted,
    required this.onForeground,
    required this.controlSurface,
    required this.scrim,
    required this.focus,
    required this.inactiveTrack,
    required this.stateHover,
    required this.statePressed,
    required this.trackUnloaded,
    required this.trackHover,
    required this.artworkFade,
    required this.floatingBars,
  });

  /// Glyphs, titles and the played track.
  final Color foreground;
  final Color foregroundSecondary;
  final Color foregroundMuted;

  /// Content on a [foreground] fill, e.g. the speed badge.
  final Color onForeground;

  /// Small surfaces drawn straight on the picture: feedback discs, the
  /// scrub time bubble.
  final Color controlSurface;

  /// Veils over the whole picture: end screen, errors, the docked player's
  /// hover state, the opening cover.
  final Color scrim;
  final Color focus;

  /// The buffered span of the seek track; also disabled glyphs.
  final Color inactiveTrack;
  final Color stateHover;
  final Color statePressed;
  final Color trackUnloaded;
  final Color trackHover;

  /// Fade behind bars drawn straight on the picture (dark mode).
  final List<Color> artworkFade;

  /// Bars sit on floating surfaces inset from the edges rather than on
  /// fades over the picture.
  final bool floatingBars;

  static const dark = PlayerColors(
    foreground: Color(0xFFFFFFFF),
    foregroundSecondary: Color(0xFFD4D4D4),
    foregroundMuted: Color(0xFFA3A3A3),
    onForeground: Color(0xFF000000),
    controlSurface: Color(0xCC000000), // black 80%
    scrim: Color(0x99000000), // black 60%
    focus: Color(0xFFFFFFFF),
    inactiveTrack: Color(0xFF888888),
    stateHover: Color(0x26FFFFFF), // white 15%
    statePressed: Color(0x40FFFFFF), // white 25%
    trackUnloaded: Color(0x4DFFFFFF), // white 30%
    trackHover: Color(0x99FFFFFF), // white 60%
    artworkFade: [Color(0x00000000), Color(0xCC000000)],
    floatingBars: false,
  );

  static const light = PlayerColors(
    foreground: Color(0xFF171717),
    foregroundSecondary: Color(0xFF4D4D4D),
    foregroundMuted: Color(0xFF606060),
    onForeground: Color(0xFFFFFFFF),
    controlSurface: Color(0xF2FFFFFF), // white 95%
    scrim: Color(0xD9F3F3F3), // surface 85%: the picture stays faintly seen
    focus: Color(0xFF171717),
    inactiveTrack: Color(0xFF8A8A8A),
    stateHover: Color(0x14000000), // black 8%
    statePressed: Color(0x24000000), // black 14%
    trackUnloaded: Color(0x26000000), // black 15%
    trackHover: Color(0x66000000), // black 40%
    artworkFade: [Color(0x00F3F3F3), Color(0x00F3F3F3)],
    floatingBars: true,
  );

  @override
  PlayerColors copyWith() => this;

  @override
  PlayerColors lerp(PlayerColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PlayerColors(
      foreground: l(foreground, other.foreground),
      foregroundSecondary: l(foregroundSecondary, other.foregroundSecondary),
      foregroundMuted: l(foregroundMuted, other.foregroundMuted),
      onForeground: l(onForeground, other.onForeground),
      controlSurface: l(controlSurface, other.controlSurface),
      scrim: l(scrim, other.scrim),
      focus: l(focus, other.focus),
      inactiveTrack: l(inactiveTrack, other.inactiveTrack),
      stateHover: l(stateHover, other.stateHover),
      statePressed: l(statePressed, other.statePressed),
      trackUnloaded: l(trackUnloaded, other.trackUnloaded),
      trackHover: l(trackHover, other.trackHover),
      artworkFade: [
        for (var i = 0; i < artworkFade.length; i++)
          l(artworkFade[i], other.artworkFade[i]),
      ],
      // A layout choice cannot blend; switch halfway.
      floatingBars: t < 0.5 ? floatingBars : other.floatingBars,
    );
  }
}
