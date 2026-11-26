import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player/models.dart';

/// A download of the viewer's that doesn't fit the download budget, even
/// after deleting what may be deleted.
class BudgetRequest {
  const BudgetRequest({
    required this.item,
    required this.bytes,
    required this.used,
    required this.budget,
    required this.suggested,
  });

  final PlaybackItem item;

  /// The download's full size.
  final int bytes;

  /// What downloads already take.
  final int used;
  final int budget;

  /// The budget raising it to would set: enough, rounded up.
  final int suggested;
}

final budgetRequestsProvider =
    NotifierProvider<BudgetRequests, List<BudgetRequest>>(BudgetRequests.new);

/// Downloads waiting on the viewer to raise the budget, oldest first. The
/// app shows each; nothing is answered without them.
class BudgetRequests extends Notifier<List<BudgetRequest>> {
  final _answers = <BudgetRequest, Completer<bool>>{};

  /// Seasons whose episodes the viewer just declined, so the rest of the
  /// season isn't asked about one by one.
  final _declined = <String, DateTime>{};
  static const _declineHolds = Duration(minutes: 2);

  static String? _season(PlaybackItem item) =>
      item.series == null ? null : '${item.series!.id}:${item.season}';

  @override
  List<BudgetRequest> build() {
    ref.onDispose(() {
      for (final answer in _answers.values) {
        answer.complete(false);
      }
    });
    return const [];
  }

  /// Completes with whether the viewer raised the budget for [request].
  Future<bool> ask(BudgetRequest request) {
    final declined = _declined[_season(request.item)];
    if (declined != null &&
        DateTime.now().difference(declined) < _declineHolds) {
      return Future.value(false);
    }
    final answer = _answers[request] = Completer<bool>();
    state = [...state, request];
    return answer.future;
  }

  void answer(BudgetRequest request, {required bool raise}) {
    if (_season(request.item) case final season? when !raise) {
      _declined[season] = DateTime.now();
    }
    _answers.remove(request)?.complete(raise);
    state = [...state.where((r) => r != request)];
  }
}
