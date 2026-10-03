import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../following/auto_downloads.dart';
import '../../../library/download_review.dart';
import '../../../player/models.dart';
import '../../../shared/errors/error_reports.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/section_header.dart';
import '../../shared/download_actions.dart';
import '../../shared/theme/theme.dart';

/// New episodes that auto-download skipped because no torrent matched
/// exactly: choose their torrents in the download review, or let them go.
class ReviewSection extends ConsumerWidget {
  const ReviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(autoDownloadReviewsProvider);
    if (reviews.isEmpty) return const SizedBox.shrink();
    final notifier = ref.read(autoDownloadReviewsProvider.notifier);
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.rule_rounded,
          title: 'Needs your choice',
          subtitle: 'New episodes without an exact match to download',
          count: '${reviews.length}',
          action: reviews.length > 1
              ? SButton.ghost(
                  label: 'Review all',
                  icon: Icons.fact_check_outlined,
                  onPressed: () =>
                      _review(ref, [for (final r in reviews) r.item]),
                )
              : null,
        ),
        const SizedBox(height: Space.s12),
        for (final (i, r) in reviews.indexed) ...[
          if (i > 0) const Divider(),
          Padding(
            padding: const EdgeInsets.all(Space.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: c.warning),
                const SizedBox(width: Space.s12),
                // Actions sit under the words so narrow windows still fit.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardTitle(itemLabel(r.item), large: true),
                      Text(
                        r.reason,
                        style: context.type.caption.copyWith(
                          color: c.foregroundSecondary,
                        ),
                      ),
                      const SizedBox(height: Space.s12),
                      Wrap(
                        spacing: Space.s8,
                        runSpacing: Space.s8,
                        children: [
                          SButton(
                            label: 'Choose torrent',
                            icon: Icons.fact_check_outlined,
                            onPressed: () => _review(ref, [r.item]),
                          ),
                          SButton.ghost(
                            label: 'Dismiss',
                            onPressed: () => notifier.dismiss(r.item.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.s48),
      ],
    );
  }
}

/// Opens [items]' torrents for the viewer; those they download leave the
/// list.
void _review(WidgetRef ref, List<PlaybackItem> items) {
  final reviews = ref.read(autoDownloadReviewsProvider.notifier);
  unawaited(
    ref
        .read(downloadReviewsProvider.notifier)
        .review(items, show: true)
        .then((queued) {
          for (final item in queued) {
            reviews.remove(item.id);
          }
        })
        .catchError((Object error) {
          ErrorReports.report("Couldn't download episodes", error);
        }),
  );
}
