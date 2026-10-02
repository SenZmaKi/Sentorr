import 'package:dio/dio.dart';

/// Lets a cancelled season stop waiting on metadata or search immediately.
Future<T> whilePlanning<T>(Future<T> work, CancelToken? cancel) {
  cancel?.throwIfCancellationRequested();
  return cancel == null
      ? work
      : Future.any([work, cancel.whenCancel.then<T>((error) => throw error)]);
}

extension PlanningCancellation on CancelToken {
  void throwIfCancellationRequested() {
    if (isCancelled) throw cancelError!;
  }
}
