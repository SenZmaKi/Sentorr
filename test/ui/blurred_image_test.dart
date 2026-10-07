import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/components/blurred_image.dart';

Future<ui.Image> _image(Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(color, BlendMode.src);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(40, 40);
  } finally {
    picture.dispose();
  }
}

class _Provider extends ImageProvider<_Provider> {
  final result = Completer<ImageInfo>();

  @override
  Future<_Provider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_Provider key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(result.future);
}

void main() {
  testWidgets('blur raster stays bounded for wide and tall viewports', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final source = await _image(const Color(0xffff0000));
      for (final size in [const Size(2000, 1000), const Size(300, 1200)]) {
        final result = await rasterizeBlurredImage(source, size, 64);
        expect(result.width, lessThanOrEqualTo(360));
        expect(result.height, lessThanOrEqualTo(720));
        final bytes = (await result.toByteData())!;
        final center =
            (result.height ~/ 2 * result.width + result.width ~/ 2) * 4;
        expect(bytes.getUint8(center), greaterThan(200));
        expect(bytes.getUint8(center + 1), lessThan(10));
        result.dispose();
      }
      expect(source.debugDisposed, isFalse);
      source.dispose();
    });
  });

  testWidgets('replaced loads stay stale and displayed raster is disposed', (
    tester,
  ) async {
    final first = _Provider(), second = _Provider();
    Widget show(ImageProvider provider, {double width = 800}) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: width,
          height: 600,
          child: BlurredImage(image: provider, sigma: 64),
        ),
      ),
    );
    await tester.pumpWidget(show(first));
    await tester.pumpWidget(show(second));
    await tester.runAsync(() async {
      first.result.complete(
        ImageInfo(image: await _image(const Color(0xffff0000))),
      );
      second.result.complete(
        ImageInfo(image: await _image(const Color(0xff0000ff))),
      );
    });
    await tester.pump();
    for (
      var i = 0;
      i < 20 && tester.widget<RawImage>(find.byType(RawImage)).image == null;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    final displayed = tester.widget<RawImage>(find.byType(RawImage)).image!;
    await tester.runAsync(() async {
      final bytes = (await displayed.toByteData())!;
      final center =
          (displayed.height ~/ 2 * displayed.width + displayed.width ~/ 2) * 4;
      expect(bytes.getUint8(center), lessThan(10));
      expect(bytes.getUint8(center + 2), greaterThan(200));
    });
    await tester.pumpWidget(show(second, width: 400));
    for (var i = 0; i < 20 && !displayed.debugDisposed; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(displayed.debugDisposed, isTrue);
    await tester.pump();
    final resized = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect(resized, isNot(same(displayed)));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(resized.debugDisposed, isTrue);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    expect(tester.takeException(), isNull);
  });
}
