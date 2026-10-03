import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_demo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders every demo page in both modes; fails on layout exceptions.
/// Set RENDER_DIR to also write PNGs for visual review.
Future<void> _loadFonts() async {
  for (final (family, files) in [
    ('Geist', ['Geist-Regular', 'Geist-Medium', 'Geist-SemiBold']),
    ('GeistMono', ['GeistMono-Regular', 'GeistMono-Medium']),
  ]) {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(
        File('assets/fonts/$f.ttf')
            .readAsBytes()
            .then((b) => b.buffer.asByteData()),
      );
    }
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons');
  final root = Platform.environment['FLUTTER_ROOT'];
  final iconFile = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconFile.existsSync()) {
    icons.addFont(iconFile.readAsBytes().then((b) => b.buffer.asByteData()));
    await icons.load();
  }
}

void main() {
  const pages = [
    'Discover',
    'Title detail',
    'Player',
    'Settings',
    'Components',
  ];
  final out = Platform.environment['RENDER_DIR'];

  testWidgets('render pages', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DesignDemoApp());

    for (final mode in ['Dark', 'Light']) {
      await tester.tap(find.text(mode));
      await tester.pump(const Duration(milliseconds: 400));
      for (final page in pages) {
        await tester.tap(find.text(page).first);
        // Buffering indicators animate forever; pump a fixed frame budget.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        // Let component transitions that start after the theme change finish.
        await tester.pump(const Duration(milliseconds: 300));
        if (out == null) continue;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final name =
              '${mode.toLowerCase()}_${page.toLowerCase().replaceAll(' ', '_')}.png';
          await File('$out/$name').writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
    }
  });

  testWidgets('dialog and toast open without errors', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DesignDemoApp());
    await tester.tap(find.text('Components'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Open dialog'));
    await tester.tap(find.text('Open dialog'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Stop streaming?'), findsOneWidget);
    await tester.tap(find.text('Keep watching'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Stop streaming?'), findsNothing);
    await tester.tap(find.text('Show toast'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Subtitles downloaded'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
