import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/budget.dart';
import '../../components/adaptive_sheet.dart';
import '../../components/buttons.dart';
import '../../components/dialog_actions.dart';
import '../../components/space_meter.dart';
import '../../shared/download_actions.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// Asks the viewer, one at a time and from wherever they are, to raise the
/// download budget for a download of theirs that doesn't fit. Dismissing
/// one keeps the budget and drops that download.
class BudgetRequestHost extends ConsumerStatefulWidget {
  const BudgetRequestHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BudgetRequestHost> createState() => _BudgetRequestHostState();
}

class _BudgetRequestHostState extends ConsumerState<BudgetRequestHost> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(budgetRequestsProvider.select((all) => all.firstOrNull), (
      _,
      request,
    ) {
      if (request != null && !_open) _show(request);
    });
  }

  Future<void> _show(BudgetRequest request) async {
    _open = true;
    final raise = await showAdaptiveSheet<bool>(
      context,
      maxWidth: 480,
      builder: (_) => _BudgetPrompt(request),
    );
    _open = false;
    if (!mounted) return;
    // Answering moves the next request up, which the listener shows.
    ref
        .read(budgetRequestsProvider.notifier)
        .answer(request, raise: raise ?? false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BudgetPrompt extends StatelessWidget {
  const _BudgetPrompt(this.request);
  final BudgetRequest request;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = request;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Not enough space for downloads',
            style: context.type.title.copyWith(color: c.foreground),
          ),
          const SizedBox(height: Space.s8),
          Text(
            '${itemLabel(r.item)} needs ${sizeLabel(r.bytes)}. Downloads '
            'already take ${sizeLabel(r.used)} of ${sizeLabel(r.budget)}, '
            "and nothing watched is left to delete. Raise the space, or "
            'delete downloads you no longer need and try again.',
            style: context.type.body.copyWith(color: c.foregroundSecondary),
          ),
          const SizedBox(height: Space.s24),
          SpaceMeter(
            budget: r.budget,
            segments: [
              SpaceSegment('Downloads', r.used, SpaceKind.kept),
              SpaceSegment('This one', r.bytes, SpaceKind.incoming),
            ],
          ),
          const SizedBox(height: Space.s24),
          DialogActions(
            children: [
              SButton.ghost(
                label: 'Skip download',
                onPressed: () => Navigator.pop(context, false),
              ),
              SButton.primary(
                label: 'Raise to ${sizeLabel(r.suggested)}',
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
