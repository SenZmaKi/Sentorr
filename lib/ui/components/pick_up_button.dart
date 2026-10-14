import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../titles/pick_up.dart';
import '../shared/play_route.dart';
import '../shared/theme/theme.dart';
import '../shared/title_format.dart';
import 'buttons.dart';
import 'motion.dart';
import 'skeleton.dart';

/// Play, or pick up where the viewer left off. A started series shows its
/// action word at once with a skeleton where the episode code will land,
/// so resolving metadata fills the slot instead of reflowing the button.
/// Titles with nothing to pick up keep a plain, natural-width Play.
class PickUpButton extends ConsumerWidget {
  const PickUpButton({super.key, required this.titleId, this.onPressed});

  final String titleId;

  /// Stays enabled while pending; [PlayMedia.playOrPickUp] awaits the lookup.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pick = ref.watch(pickUpPresentationProvider(titleId));
    final pending =
        pick?.pending == true && !ref.watch(pickUpProvider(titleId)).hasError;
    final item = pick?.item;
    final code = item != null && item.isEpisode
        ? episodeCode(item.season, item.episode)
        : null;
    if (!pending && code == null) {
      return SButton.primary(
        label: pickUpLabel(pick),
        icon: Icons.play_arrow_rounded,
        onPressed: onPressed,
      );
    }
    final verb = pick!.resume ? 'Resume' : 'Continue';
    return SButton.primary(
      label: pending ? '$verb, loading episode' : pickUpLabel(pick),
      icon: Icons.play_arrow_rounded,
      onPressed: onPressed,
      labelContent: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$verb '),
            // A placeholder wraps as one unit at large text scales.
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: EpisodeCodeSlot(code: code),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// The episode code, or a skeleton sized like a typical one while [code]
/// is null. The swap crossfades and any width difference eases.
class EpisodeCodeSlot extends StatelessWidget {
  const EpisodeCodeSlot({super.key, this.code});

  final String? code;

  @override
  Widget build(BuildContext context) {
    final current = switch (code) {
      final code? => Text(code, key: ValueKey(code)),
      null => const Skeleton.text(key: ValueKey('skeleton'), sample: 'S1 E10'),
    };
    // A zero-length AnimatedSize re-dirties itself mid-layout, so reduced
    // motion swaps immediately without the transition wrappers.
    if (reduceMotion(context)) return current;
    return AnimatedSize(
      duration: Motion.panel,
      curve: Motion.change,
      alignment: AlignmentDirectional.centerStart,
      child: AnimatedSwitcher(
        duration: Motion.panel,
        switchInCurve: Motion.enter,
        switchOutCurve: Motion.enter,
        layoutBuilder: (current, previous) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [...previous, ?current],
        ),
        child: current,
      ),
    );
  }
}
