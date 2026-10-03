import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/download_review.dart';
import '../../components/adaptive_sheet.dart';
import 'review_dialog.dart';

/// Shows each download review the viewer should see, one at a time, from
/// wherever Download was pressed. Dismissing one cancels it.
class DownloadReviewHost extends ConsumerStatefulWidget {
  const DownloadReviewHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DownloadReviewHost> createState() => _DownloadReviewHostState();
}

class _DownloadReviewHostState extends ConsumerState<DownloadReviewHost> {
  bool _open = false;

  static int? _shown(List<DownloadReview> all) =>
      all.where((r) => r.shown).firstOrNull?.id;

  @override
  void initState() {
    super.initState();
    ref.listenManual(downloadReviewsProvider.select(_shown), (_, id) {
      if (id != null && !_open) _show(id);
    });
  }

  Future<void> _show(int id) async {
    _open = true;
    await showAdaptiveSheet<void>(
      context,
      framed: false,
      builder: (_) => ReviewDialog(id: id),
    );
    _open = false;
    if (!mounted) return;
    final reviews = ref.read(downloadReviewsProvider.notifier);
    // Barrier, Escape or Back closed it; a finished review is already gone.
    reviews.cancel(id);
    final next = _shown(ref.read(downloadReviewsProvider));
    if (next != null) _show(next);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
