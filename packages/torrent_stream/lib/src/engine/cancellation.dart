import 'dart:async';

class ReadCancelled implements Exception {
  const ReadCancelled();
  @override
  String toString() => 'Read cancelled';
}

class Cancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>{};
  bool get isCancelled => _cancelled;
  void cancel() {
    if (isCancelled) return;
    _cancelled = true;
    for (final listener in _listeners.toList()) {
      listener();
    }
    _listeners.clear();
  }

  void check() {
    if (isCancelled) throw const ReadCancelled();
  }

  Future<T> wait<T>(Future<T> operation) {
    // The caller has already started operation (e.g. socket.flush()). Even
    // an already-cancelled wait must observe its eventual error.
    unawaited(operation.then<void>((_) {}, onError: (Object _) {}));
    check();
    final result = Completer<T>();
    void cancelled() {
      if (!result.isCompleted) result.completeError(const ReadCancelled());
    }

    _listeners.add(cancelled);
    operation.then(
      (value) {
        if (!result.isCompleted) result.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    // Remove each waiter when it finishes. A single long HTTP request must not
    // retain one cancellation callback per chunk consumed over its lifetime.
    return result.future.whenComplete(() => _listeners.remove(cancelled));
  }
}
