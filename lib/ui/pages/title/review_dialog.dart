import 'package:flutter/material.dart';

import '../../../imdb/models.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/surface.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// "ana_k · Mar 4, 2024".
String? reviewByline(ImdbReview r) {
  final date = DateTime.tryParse(r.submissionDate ?? '');
  final parts = [?r.author, if (date != null) dateLabel(date)];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The full text of a review, in the dialog contract: floating, radius 16,
/// padding 24, readable width.
Future<void> showReview(BuildContext context, ImdbReview review) =>
    showDialog<void>(
      context: context,
      barrierColor: OverlayColors.scrim,
      builder: (context) => _ReviewDialog(review),
    );

class _ReviewDialog extends StatelessWidget {
  const _ReviewDialog(this.review);

  final ImdbReview review;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    final r = review;
    final byline = reviewByline(r);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(Space.s24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: DepthBox(
          style: context.depth.of(SurfaceDepth.floating),
          radius: Radii.panel,
          border: Border.all(color: c.borderStrong),
          padding: const EdgeInsets.all(Space.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.title ?? 'Review',
                style: type.title.copyWith(color: c.foreground),
              ),
              const SizedBox(height: Space.s8),
              MetaLine([
                if (r.rating != null)
                  MetaItem(
                    '${r.rating}/10',
                    icon: Icons.star_rounded,
                    technical: true,
                  ),
                if (byline != null) MetaItem(byline),
                if (r.upVotes != null)
                  MetaItem(
                    compactCount(r.upVotes!),
                    icon: Icons.thumb_up_outlined,
                    technical: true,
                  ),
                if (r.downVotes != null)
                  MetaItem(
                    compactCount(r.downVotes!),
                    icon: Icons.thumb_down_outlined,
                    technical: true,
                  ),
              ], style: type.bodySmall),
              const SizedBox(height: Space.s16),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    r.content ?? '',
                    style: type.body.copyWith(color: c.foregroundSecondary),
                  ),
                ),
              ),
              const SizedBox(height: Space.s24),
              Align(
                alignment: Alignment.centerRight,
                child: SButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
