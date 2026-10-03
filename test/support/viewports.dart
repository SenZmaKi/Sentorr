import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/shared/layout/adaptive.dart';

/// A named window size and the input mode it is normally used with.
typedef TestViewport = ({String name, Size size, InputMode input});

/// The shared responsive matrix; every page should lay out cleanly at each.
const List<TestViewport> viewports = [
  (name: 'phone portrait', size: Size(360, 740), input: InputMode.touch),
  (name: 'phone tall', size: Size(390, 844), input: InputMode.touch),
  (name: 'phone landscape', size: Size(844, 390), input: InputMode.touch),
  (name: 'phone landscape small', size: Size(740, 360), input: InputMode.touch),
  (name: 'tablet portrait', size: Size(820, 1180), input: InputMode.touch),
  (name: 'tablet landscape', size: Size(1180, 820), input: InputMode.touch),
  (name: 'small window', size: Size(800, 600), input: InputMode.pointer),
  (name: 'laptop', size: Size(1280, 800), input: InputMode.pointer),
  (name: 'desktop', size: Size(1920, 1080), input: InputMode.pointer),
  (name: 'ultrawide', size: Size(2560, 1440), input: InputMode.pointer),
];

/// Sizes the test window to [viewport], reset after the test.
void useViewport(WidgetTester tester, TestViewport viewport) {
  tester.view.physicalSize = viewport.size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Wraps [child] in the viewport's input mode.
Widget withInput(TestViewport viewport, Widget child) =>
    AdaptiveScope(input: viewport.input, child: child);
