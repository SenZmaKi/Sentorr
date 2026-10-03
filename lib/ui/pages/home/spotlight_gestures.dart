import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// The spotlight's touch path for what a pointer gets from hover: a finger
/// resting on the hero pauses it ([onTouch]), and a horizontal swipe moves
/// to the next or previous title ([onSwipe] with +1 or -1). Mouse drags are
/// ignored so text selection and pointer gestures behave as before.
class SpotlightGestures extends StatelessWidget {
  const SpotlightGestures({
    super.key,
    required this.onTouch,
    required this.onSwipe,
    required this.child,
  });

  final VoidCallback onTouch;
  final ValueChanged<int> onSwipe;
  final Widget child;

  /// Flings slower than this are drags that changed their mind.
  static const _minVelocity = 200.0;

  static const _fingers = {PointerDeviceKind.touch, PointerDeviceKind.stylus};

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) {
      if (_fingers.contains(e.kind)) onTouch();
    },
    child: GestureDetector(
      supportedDevices: _fingers,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < _minVelocity) return;
        // Swiping left reveals the next title, as in a carousel.
        onSwipe(v < 0 ? 1 : -1);
      },
      child: child,
    ),
  );
}
