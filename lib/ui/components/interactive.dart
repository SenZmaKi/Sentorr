import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/layout/adaptive.dart';
import '../shared/theme/theme.dart';

/// Control labels name their keyboard shortcut in a trailing "(k)" or
/// "(Shift+N)". Touch has no keyboard to use it, so the suffix is dropped
/// there from both tooltip and spoken label.
String shortcutLabel(BuildContext context, String label) =>
    context.input.isTouch ? label.replaceFirst(_shortcutSuffix, '') : label;

final _shortcutSuffix = RegExp(
  r'\s*\((?:(?:Shift|Ctrl|Alt|Cmd)\+)?[^\s()]{1,3}\)$',
);

/// Resolved interaction state handed to [Interactive.builder].
class InteractionState {
  const InteractionState({
    required this.hovered,
    required this.pressed,
    required this.focused,
    required this.enabled,
  });

  final bool hovered;
  final bool pressed;
  final bool focused;
  final bool enabled;
}

/// Shared hover/press/focus/keyboard behavior with the central focus ring:
/// 2 units wide, 2 units outside the component boundary.
class Interactive extends StatefulWidget {
  const Interactive({
    super.key,
    required this.builder,
    this.onTap,
    this.borderRadius = Radii.control,
    this.semanticLabel,
    this.selected,
    this.button = true,
    this.focusColor,
    this.excludeChildSemantics = true,
  });

  final Widget Function(BuildContext context, InteractionState state) builder;
  final VoidCallback? onTap;
  final double borderRadius;
  final String? semanticLabel;
  final bool? selected;
  final bool button;

  /// Overlay contexts (player) supply their own focus role.
  final Color? focusColor;

  /// Keep nested independent controls accessible when a tile has links.
  final bool excludeChildSemantics;

  @override
  State<Interactive> createState() => _InteractiveState();
}

class _InteractiveState extends State<Interactive> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final state = InteractionState(
      hovered: _enabled && _hovered,
      pressed: _enabled && _pressed,
      focused: _focused,
      enabled: _enabled,
    );
    final ring = widget.focusColor ?? context.colors.focus;
    return Semantics(
      button: widget.button,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap?.call(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          onTap: widget.onTap,
          child: CustomPaint(
            foregroundPainter: _FocusRingPainter(
              visible: _focused,
              color: ring,
              radius: widget.borderRadius,
            ),
            // A semantic label replaces the visual text so it isn't read twice.
            child: widget.semanticLabel == null || !widget.excludeChildSemantics
                ? widget.builder(context, state)
                : ExcludeSemantics(child: widget.builder(context, state)),
          ),
        ),
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({
    required this.visible,
    required this.color,
    required this.radius,
  });

  final bool visible;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    const gap = Borders.focus;
    const width = Borders.focus;
    final rect = (Offset.zero & size).inflate(gap + width / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius + gap + width / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.visible != visible || old.color != color || old.radius != radius;
}
