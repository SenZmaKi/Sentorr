import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'chips.dart';
import 'skeleton.dart';

/// Uses the chip's actual scaled height; only its label is a placeholder.
class SeasonChipsLoading extends StatelessWidget {
  const SeasonChipsLoading({super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.all(Space.s4),
    child: Row(
      spacing: Space.s8,
      children: [
        for (var n = 0; n < 3; n++)
          Stack(
            alignment: Alignment.center,
            children: [
              const Visibility(
                visible: false,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: SChip(label: 'Season 99'),
              ),
              Skeleton.text(sample: 'Season 99', style: context.type.label),
            ],
          ),
      ],
    ),
  );
}
