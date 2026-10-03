import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'interactive.dart';
import 'surface.dart';

/// On/off switch: a recessed track that fills with the action color when
/// on, carrying a raised thumb. Position and fill both show the state.
class SToggle extends StatelessWidget {
  const SToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  static const _width = 40.0, _height = 24.0, _thumb = 18.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = context.depth;
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      child: Interactive(
        onTap: enabled ? () => onChanged!(!value) : null,
        semanticLabel: semanticLabel,
        borderRadius: Radii.full,
        builder: (context, s) => MinTarget(
          child: Opacity(
            opacity: enabled ? 1 : .45,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                value
                    ? AnimatedContainer(
                        duration: Motion.hover,
                        width: _width,
                        height: _height,
                        decoration: BoxDecoration(
                          color: s.hovered ? c.actionHover : c.action,
                          borderRadius: BorderRadius.circular(Radii.full),
                        ),
                      )
                    : DepthBox(
                        style: d.of(SurfaceDepth.inset),
                        radius: Radii.full,
                        width: _width,
                        height: _height,
                        border: Border.all(color: c.borderControl),
                      ),
                AnimatedPositioned(
                  duration: Motion.hover,
                  curve: Curves.easeOut,
                  left: value ? _width - _thumb - 3 : 3,
                  child: value
                      ? Container(
                          width: _thumb,
                          height: _thumb,
                          decoration: BoxDecoration(
                            color: c.onAction,
                            shape: BoxShape.circle,
                          ),
                        )
                      : DepthBox(
                          style: d.of(SurfaceDepth.raised),
                          radius: Radii.full,
                          width: _thumb,
                          height: _thumb,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
