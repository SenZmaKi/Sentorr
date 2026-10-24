import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../titles/pick_up.dart';
import '../shared/play_route.dart';
import '../shared/theme/theme.dart';
import 'buttons.dart';
import 'skeleton.dart';

/// A text skeleton while the next episode resolves. All states
/// reserve the same space, measured with the active typography and scale.
class PickUpButton extends ConsumerWidget {
  const PickUpButton({
    super.key,
    required this.titleId,
    this.onPressed,
    this.onCaughtUp,
  });

  final String titleId;
  final VoidCallback? onPressed;
  final VoidCallback? onCaughtUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pick = ref.watch(pickUpPresentationProvider(titleId));
    final failed =
        pick?.pending == true && ref.watch(pickUpProvider(titleId)).hasError;
    final pending = pick?.pending == true && !failed;
    final label = failed ? 'Retry continue' : pickUpLabel(pick);
    return LayoutBuilder(
      builder: (context, constraints) {
        const chrome = Space.s16 * 2 + IconSizes.control + Space.s8;
        final painter = TextPainter(
          text: TextSpan(text: 'Continue S99 E99', style: context.type.label),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final width = constraints.constrainWidth(painter.width + chrome);
        // Reserve wrapped height too, so narrow layouts and larger text
        // don't move neighbouring actions when loading finishes.
        painter.layout(maxWidth: (width - chrome).clamp(1, double.infinity));
        final height = constraints.constrainHeight(
          painter.height.clamp(context.density.control, double.infinity),
        );
        painter.dispose();
        return SizedBox(
          width: width,
          height: height,
          child: SButton.primary(
            label: pending ? 'Loading playback action' : label,
            labelContent: pending
                ? const Skeleton.text(sample: 'Continue S99 E99')
                : null,
            icon: pick?.caughtUp == true
                ? Icons.video_library_outlined
                : Icons.play_arrow_rounded,
            onPressed: pick?.caughtUp == true
                ? onCaughtUp ?? onPressed
                : onPressed,
          ),
        );
      },
    );
  }
}
