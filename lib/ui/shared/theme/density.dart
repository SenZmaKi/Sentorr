import 'package:flutter/widgets.dart';

import '../layout/adaptive.dart';
import 'tokens.dart';

/// Control sizing resolved from the input mode (DESIGN.md "Control minimum
/// height": 40 standard, 36 compact rows, 48 touch). Components read
/// `context.density` so no screen sizes controls for touch itself.
///
/// Heights are minimums: controls grow with text scaling rather than clip.
@immutable
class SentorrDensity {
  const SentorrDensity._({
    required this.control,
    required this.iconButton,
    required this.menuRow,
    required this.minTarget,
  });

  /// Mouse, trackpad and keyboard.
  static const pointer = SentorrDensity._(
    control: ControlHeights.standard,
    iconButton: ControlHeights.standard,
    menuRow: ControlHeights.compact,
    minTarget: 0,
  );

  /// Fingers: every control and row reaches 48.
  static const touch = SentorrDensity._(
    control: ControlHeights.touch,
    iconButton: ControlHeights.touch,
    menuRow: ControlHeights.touch,
    minTarget: ControlHeights.touch,
  );

  static SentorrDensity of(InputMode input) => input.isTouch ? touch : pointer;

  /// Minimum height of buttons, inputs and selects.
  final double control;

  /// Square target of icon buttons.
  final double iconButton;

  /// Minimum height of menu and list rows.
  final double menuRow;

  /// Minimum hit region of visually small controls (chips, switches, pager
  /// dots, the seek bar); 0 leaves them at their drawn size.
  final double minTarget;

  bool get isTouch => minTarget > 0;
}

extension DensityContext on BuildContext {
  SentorrDensity get density => SentorrDensity.of(input);
}

/// Grows a visually small control's hit region to [SentorrDensity.minTarget]
/// on touch, centring its drawing; on pointer it adds nothing. Place it
/// inside the control's gesture detector so the extra area responds.
class MinTarget extends StatelessWidget {
  const MinTarget({super.key, required this.child, this.axis});

  final Widget child;

  /// Inflate only along this axis, e.g. a full-width seek bar.
  final Axis? axis;

  @override
  Widget build(BuildContext context) {
    final min = context.density.minTarget;
    if (min == 0) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: axis == Axis.vertical ? 0 : min,
        minHeight: axis == Axis.horizontal ? 0 : min,
      ),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
