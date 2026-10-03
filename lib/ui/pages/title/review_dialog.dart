import 'package:flutter/material.dart';

import '../../../imdb/models.dart';
import '../../components/adaptive_sheet.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/dialog_actions.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// "ana_k · Mar 4, 2024".
String? reviewByline(ImdbReview r) {
  final date = DateTime.tryParse(r.submissionDate ?? '');
  final parts = [?r.author, if (date != null) dateLabel(date)];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The full text of a review: the dialog contract (floating, radius 16,
/// padding 24, readable width) from medium, a bottom sheet on a phone and
/// as tall as a short window allows.
Future<void> showReview(BuildContext context, ImdbReview review) =>
    showAdaptiveSheet<void>(
      context,
      maxWidth: 720,
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
    return Column(
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
        DialogActions(
          children: [
            SButton(
              label: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}
