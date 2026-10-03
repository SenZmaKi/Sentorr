import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../components/surface.dart';
import '../../shared/theme/theme.dart';
import 'shortcut_map.dart';

/// One cap: its id in [PlayerShortcut.keys], printed legend, the shifted
/// legend above it, and width in key units.
typedef _Key = ({String id, String label, String? shifted, double width});

_Key _k(String id, {String? label, String? shifted, double width = 1}) =>
    (id: id, label: label ?? id.toUpperCase(), shifted: shifted, width: width);

List<_Key> _letters(String row) => [for (final c in row.split('')) _k(c)];

final _mac = defaultTargetPlatform == TargetPlatform.macOS;

/// A 15-unit compact layout, as on a laptop. The bottom row ends in the
/// arrow cluster, drawn separately.
final _rows = <List<_Key>>[
  [
    _k('esc', label: 'esc'),
    for (final d in '1234567890'.split('')) _k(d),
    _k('-', shifted: '_'),
    _k('=', shifted: '+'),
    _k('backspace', label: '⌫', width: 2),
  ],
  [
    _k('tab', label: 'tab', width: 1.5),
    ..._letters('qwertyuiop'),
    _k('[', shifted: '{'),
    _k(']', shifted: '}'),
    _k(r'\', shifted: '|', width: 1.5),
  ],
  [
    _k('caps', label: 'caps', width: 1.75),
    ..._letters('asdfghjkl'),
    _k(';', shifted: ':'),
    _k("'", shifted: '"'),
    _k('enter', label: _mac ? 'return' : 'enter', width: 2.25),
  ],
  [
    _k('shift', label: 'shift', width: 2.25),
    ..._letters('zxcvbnm'),
    _k(',', shifted: '<'),
    _k('.', shifted: '>'),
    _k('/', shifted: '?'),
    _k('shift', label: 'shift', width: 2.75),
  ],
  [
    _k('ctrl', label: _mac ? 'control' : 'ctrl', width: 1.25),
    _k('alt', label: _mac ? 'option' : 'alt', width: 1.25),
    _k('meta', label: _mac ? 'cmd' : 'win', width: 1.5),
    _k('space', label: 'space', width: 5.5),
    _k('meta', label: _mac ? 'cmd' : 'win', width: 1.5),
    _k('alt', label: _mac ? 'option' : 'alt'),
  ],
];

/// The player's shortcuts on a keyboard: bound keys are raised caps with
/// their glyphs, the rest faint outlines, all set into a recessed deck.
/// Hovering or tapping a bound key lights it and its commands in [lit].
class ShortcutKeyboard extends StatelessWidget {
  const ShortcutKeyboard({super.key, required this.lit});

  final LitShortcuts lit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // 15 units across with gaps of a tenth of a unit, plus the deck's rim.
      final unit = box.maxWidth / 16.8;
      final gap = unit / 10;
      Widget cap(_Key k, {double? height}) =>
          _Cap(k: k, lit: lit, height: height ?? unit);
      Widget row(List<_Key> keys, {Widget? end}) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, k) in keys.indexed) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(flex: (k.width * 100).round(), child: cap(k)),
          ],
          if (end != null) ...[SizedBox(width: gap), end],
        ],
      );
      final half = (unit - gap) / 2;
      final arrows = Expanded(
        flex: 300,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: cap(_k('left', label: '←'), height: half),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cap(_k('up', label: '↑'), height: half),
                  SizedBox(height: gap),
                  cap(_k('down', label: '↓'), height: half),
                ],
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: cap(_k('right', label: '→'), height: half),
            ),
          ],
        ),
      );
      return ExcludeSemantics(
        child: MouseRegion(
          onExit: (_) => lit.value = const {},
          child: DepthBox(
            style: context.depth.of(SurfaceDepth.inset),
            radius: Radii.card,
            padding: EdgeInsets.all(gap * 4),
            child: Column(
              children: [
                for (final (i, keys) in _rows.indexed) ...[
                  if (i > 0) SizedBox(height: gap),
                  row(keys, end: i == _rows.length - 1 ? arrows : null),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Cap extends StatelessWidget {
  const _Cap({required this.k, required this.lit, required this.height});

  final _Key k;
  final LitShortcuts lit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bound = boundKeys.contains(k.id);
    if (!bound) {
      return MouseRegion(
        onEnter: (_) => lit.value = const {},
        child: _face(context, bound: false, on: false),
      );
    }
    final mine = shortcutsOn(k.id);
    return ValueListenableBuilder(
      valueListenable: lit,
      builder: (context, shown, _) {
        final on = shown.any((s) => s.keys.contains(k.id));
        // No clearing on exit: the gaps between caps would blink the
        // highlight off and on. The deck clears it when the pointer leaves.
        return MouseRegion(
          onEnter: (_) => lit.value = mine,
          child: GestureDetector(
            onTap: () => lit.value = setEquals(shown, mine) ? const {} : mine,
            child: _face(context, bound: true, on: on),
          ),
        );
      },
    );
  }

  Widget _face(BuildContext context, {required bool bound, required bool on}) {
    final c = context.colors;
    final raised = context.depth.of(SurfaceDepth.raised);
    final style = !bound
        ? DepthStyle(fill: c.surfaceInset)
        : on
        ? DepthStyle(
            fill: c.action,
            shadows: raised.shadows,
            edgeHighlight: raised.edgeHighlight,
            edgeShade: raised.edgeShade,
          )
        : raised;
    final ink = on
        ? c.onAction
        : bound
        ? c.foreground
        : c.foregroundDisabled;
    final word = k.label.length > 1 && k.id.length > 1;
    final type = context.type;
    final legendStyle = (word ? type.caption : type.label).copyWith(color: ink);
    final legend = switch (capIcons[k.label]) {
      final icon? => Icon(icon, size: IconSizes.control, color: ink),
      null => Text(k.label, style: legendStyle),
    };
    // A shifted legend is the meaning itself (< > ?), so it takes no glyph.
    final glyph = k.shifted == null ? keyGlyphs[k.id] : null;
    return DepthBox(
      style: style,
      // Lit switches at once: a fade passes through grey under ink that
      // has already flipped, which reads as a flicker.
      duration: Duration.zero,
      radius: Radii.chip,
      height: height,
      border: bound ? null : Border.all(color: c.borderSubtle),
      padding: EdgeInsets.all(height / 10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (k.shifted case final shifted?)
              Text(
                shifted,
                style: type.caption.copyWith(
                  color: on ? c.onAction : ink.withValues(alpha: 0.6),
                ),
              ),
            legend,
            if (glyph != null)
              Icon(glyph, size: IconSizes.metadata, color: ink),
          ],
        ),
      ),
    );
  }
}
