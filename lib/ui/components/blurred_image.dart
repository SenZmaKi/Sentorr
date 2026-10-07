import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

/// Rasterize a decorative blur at low resolution once, then scale its result.
/// Filtering the enlarged widget would allocate viewport-sized intermediates.
class BlurredImage extends StatefulWidget {
  const BlurredImage({super.key, required this.image, required this.sigma});

  final ImageProvider image;
  final double sigma;

  @override
  State<BlurredImage> createState() => _BlurredImageState();
}

class _BlurredImageState extends State<BlurredImage> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_loaded, onError: _failed);
  ImageInfo? _source;
  ui.Image? _blurred;
  Size? _size;
  int _revision = 0;
  bool _scheduled = false;
  bool _rendering = false;
  bool _dirty = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(BlurredImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
    if (oldWidget.sigma != widget.sigma) _invalidate();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _stream?.removeListener(_listener);
    _source?.dispose();
    _source = null;
    _blurred?.dispose();
    _blurred = null;
    _revision++;
    _stream = stream..addListener(_listener);
  }

  void _loaded(ImageInfo info, bool synchronousCall) {
    _source?.dispose();
    _source = info;
    _invalidate();
  }

  void _failed(Object error, StackTrace? stack) {
    // Decorative artwork remains empty if fetching/decoding fails.
    _revision++;
    _source?.dispose();
    _source = null;
    _blurred?.dispose();
    _blurred = null;
    if (mounted) setState(() {});
  }

  void _invalidate() {
    _revision++;
    _dirty = true;
    if (_scheduled || _rendering || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _render();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _render() async {
    final source = _source;
    final size = _size;
    if (source == null || size == null || size.isEmpty) return;
    _rendering = true;
    _dirty = false;
    final revision = _revision;
    // Keep the source alive independently of stream changes/disposal.
    final image = source.image.clone();
    try {
      final result = await rasterizeBlurredImage(image, size, widget.sigma);
      if (!mounted || revision != _revision) {
        result.dispose();
      } else {
        final previous = _blurred;
        setState(() => _blurred = result);
        previous?.dispose();
      }
    } catch (error, stack) {
      Logger('sentorr.images')
          .warning('Could not rasterize ambient artwork', error, stack);
    } finally {
      image.dispose();
      _rendering = false;
      if (mounted && _dirty) _invalidate();
    }
  }

  @override
  void dispose() {
    _revision++;
    _stream?.removeListener(_listener);
    _source?.dispose();
    _blurred?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = box.biggest;
      if (size.isFinite && size != _size) {
        _size = size;
        _invalidate();
      }
      return RawImage(image: _blurred, fit: BoxFit.fill);
    },
  );
}

/// Preserve cover cropping and logical blur radius while bounding the raster.
Future<ui.Image> rasterizeBlurredImage(
  ui.Image source,
  Size size,
  double sigma,
) async {
  assert(size.isFinite && !size.isEmpty);
  assert(sigma.isFinite && sigma >= 0);
  final scale = math.min(360 / size.width, 720 / size.height);
  final width = (size.width * scale).ceil().clamp(1, 360);
  final height = (size.height * scale).ceil().clamp(1, 720);
  final output = Size(width.toDouble(), height.toDouble());
  final input = Size(source.width.toDouble(), source.height.toDouble());
  final fitted = applyBoxFit(BoxFit.cover, input, output);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // Filter the cropped layer, matching ImageFiltered, rather than filtering
  // the source image before its cover crop is applied.
  canvas.saveLayer(
    Offset.zero & output,
    Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma * width / size.width,
        sigmaY: sigma * height / size.height,
      ),
  );
  canvas.drawImageRect(
    source,
    Alignment.center.inscribe(fitted.source, Offset.zero & input),
    Offset.zero & output,
    Paint()..filterQuality = FilterQuality.low,
  );
  canvas.restore();
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}
