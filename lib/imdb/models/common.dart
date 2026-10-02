class ImdbImage {
  const ImdbImage({
    required this.url,
    this.width,
    this.height,
    this.id,
    this.type,
  });
  final String url;
  final int? width;
  final int? height;
  final String? id;
  final String? type;
  bool get isLandscape => width != null && height != null && width! > height!;
}

class ImdbDate {
  const ImdbDate({this.year, this.month, this.day});
  final int? year;
  final int? month;
  final int? day;
}

class ImdbPage<T> {
  ImdbPage({required List<T> items, this.nextCursor, this.total})
    : items = List.unmodifiable(items);
  final List<T> items;
  final String? nextCursor;
  final int? total;
}

class ImdbException implements Exception {
  const ImdbException(
    this.message, {
    this.codes = const [],
    this.paths = const [],
  });
  final String message;
  final List<String> codes;
  final List<List<Object?>> paths;
  @override
  String toString() => 'ImdbException: $message';
}
