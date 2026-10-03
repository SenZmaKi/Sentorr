import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'adaptive_sheet.dart';
import 'buttons.dart';
import 'dialog_actions.dart';

/// Asks before an action that can't be undone; true when confirmed. A
/// bottom sheet on a phone, the floating dialog elsewhere.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final result = await showAdaptiveSheet<bool>(
    context,
    maxWidth: 440,
    builder: (context) {
      final c = context.colors;
      // All of it scrolls: in a short window at large text even the title
      // and actions may not fit.
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.type.title.copyWith(color: c.foreground),
            ),
            const SizedBox(height: Space.s8),
            Text(
              message,
              style: context.type.body.copyWith(color: c.foregroundSecondary),
            ),
            const SizedBox(height: Space.s24),
            DialogActions(
              children: [
                SButton.ghost(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(context, false),
                ),
                destructive
                    ? SButton.destructive(
                        label: confirmLabel,
                        onPressed: () => Navigator.pop(context, true),
                      )
                    : SButton.primary(
                        label: confirmLabel,
                        onPressed: () => Navigator.pop(context, true),
                      ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}
