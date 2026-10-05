/// Runs [operation] with at most [maxConcurrent] items in flight while
/// preserving the input order in the returned list.
Future<List<R>> parallelMapOrdered<T, R>(
  Iterable<T> values, {
  required int maxConcurrent,
  required Future<R> Function(T value) operation,
}) async {
  if (maxConcurrent < 1) {
    throw ArgumentError.value(
      maxConcurrent,
      'maxConcurrent',
      'Must be positive.',
    );
  }

  final items = values.toList(growable: false);
  if (items.isEmpty) return <R>[];

  final results = List<Object?>.filled(items.length, null);
  var nextIndex = 0;
  var stopped = false;

  Future<void> worker() async {
    while (!stopped) {
      final index = nextIndex++;
      if (index >= items.length) return;
      try {
        results[index] = await operation(items[index]);
      } catch (_) {
        stopped = true;
        rethrow;
      }
    }
  }

  await Future.wait(
    List.generate(
      items.length < maxConcurrent ? items.length : maxConcurrent,
      (_) => worker(),
    ),
  );
  return List<R>.generate(items.length, (index) => results[index] as R);
}
