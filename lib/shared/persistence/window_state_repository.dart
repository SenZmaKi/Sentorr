import 'json_file_store.dart';

class WindowBounds {
  final double x;
  final double y;
  final double width;
  final double height;

  const WindowBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  static WindowBounds? fromJson(Map<String, dynamic> json) {
    final x = _doubleValue(json['x']);
    final y = _doubleValue(json['y']);
    final width = _doubleValue(json['width']);
    final height = _doubleValue(json['height']);
    if (x == null ||
        y == null ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0) {
      return null;
    }
    return WindowBounds(x: x, y: y, width: width, height: height);
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class WindowStateRepository {
  WindowStateRepository({required this.store});
  final JsonFileStore store;
  Future<WindowBounds?> load() async {
    final json = await store.read();
    return json == null ? null : WindowBounds.fromJson(json);
  }

  Future<void> save(WindowBounds bounds) => store.write(bounds.toJson());
}

double? _doubleValue(Object? value) {
  if (value is! num) return null;
  final parsed = value.toDouble();
  return parsed.isFinite ? parsed : null;
}
