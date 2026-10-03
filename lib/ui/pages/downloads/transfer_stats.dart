import 'package:flutter/material.dart';

import '../../components/cards/card_parts.dart';
import '../../shared/theme/theme.dart';

/// A transfer's facts (size, speeds, seeds, peers, time left) as caption
/// items that wrap onto more lines rather than truncate, since each one
/// matters while a download runs.
class TransferStats extends StatelessWidget {
  const TransferStats(this.items, {super.key});

  final List<MetaItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = context.type.caption.copyWith(color: c.foregroundSecondary);
    return Wrap(
      spacing: Space.s12,
      runSpacing: Space.s2,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 14, color: c.foregroundMuted),
                const SizedBox(width: Space.s4),
              ],
              Text(
                item.label,
                style: item.technical
                    ? context.type.technical.copyWith(
                        color: base.color,
                        fontSize: base.fontSize,
                        height: base.height,
                      )
                    : base,
              ),
            ],
          ),
      ],
    );
  }
}
