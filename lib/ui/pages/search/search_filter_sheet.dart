import 'package:flutter/material.dart';

import '../../components/buttons.dart';
import '../../components/dialog_actions.dart';
import '../../shared/theme/theme.dart';
import 'search_filters.dart';

/// The search filters on a phone, in an adaptive sheet: they apply as they
/// change, so the results are already right when Done closes it. The
/// range inputs scroll above the keyboard with the sheet.
class SearchFilterSheet extends StatelessWidget {
  const SearchFilterSheet({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Filters',
        style: context.type.title.copyWith(color: context.colors.foreground),
      ),
      const SizedBox(height: Space.s16),
      const Flexible(child: SingleChildScrollView(child: SearchFilters())),
      const SizedBox(height: Space.s24),
      DialogActions(
        children: [
          SButton.primary(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ],
  );
}
