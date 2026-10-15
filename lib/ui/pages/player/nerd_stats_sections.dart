import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';
import 'stats_readout.dart';

/// Stats for nerds' labelled rows, by section; split into two columns when
/// there is room, keeping each section whole.
class StatsSectionList extends StatelessWidget {
  const StatsSectionList({super.key, required this.sections, this.columns = 1});

  final List<StatsSection> sections;
  final int columns;

  @override
  Widget build(BuildContext context) {
    if (columns < 2) return _column(context, sections);
    // Balance by row count, so neither column runs long.
    final total = sections.fold<int>(0, (n, s) => n + s.rows.length + 1);
    var split = 0, rows = 0;
    while (split < sections.length && rows < total / 2) {
      rows += sections[split++].rows.length + 1;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _column(context, sections.sublist(0, split))),
        const SizedBox(width: Space.s16),
        Expanded(child: _column(context, sections.sublist(split))),
      ],
    );
  }

  Widget _column(BuildContext context, List<StatsSection> sections) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final section in sections) ...[
        Padding(
          padding: const EdgeInsets.only(top: Space.s8, bottom: Space.s2),
          child: Text(
            section.title.toUpperCase(),
            style: context.type.caption.copyWith(
              color: OverlayColors.foregroundMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        for (final (label, value) in section.rows) _row(context, label, value),
      ],
    ],
  );

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(right: Space.s8, top: 1, bottom: 1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: context.type.caption.copyWith(
              color: OverlayColors.foregroundSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: Space.s12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: context.type.technical.copyWith(
              color: OverlayColors.foreground,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}
