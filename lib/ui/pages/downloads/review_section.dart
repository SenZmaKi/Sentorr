import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../following/auto_downloads.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/section_header.dart';
import '../../shared/download_actions.dart';
import '../../shared/theme/theme.dart';

/// New episodes that auto-download skipped because no torrent matched
/// exactly: download the closest match or let them go.
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
        ),
        const SizedBox(height: Space.s12),
        for (final (i, r) in reviews.indexed) ...[
          if (i > 0) const Divider(),
          Padding(
            padding: const EdgeInsets.all(Space.s12),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: c.warning),
                const SizedBox(width: Space.s12),
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
                    ],
                  ),
                ),
                const SizedBox(width: Space.s8),
                Wrap(
                  spacing: Space.s8,
                  runSpacing: Space.s8,
                  children: [
                    SButton(
                      label: 'Download closest',
                      icon: Icons.download_rounded,
                      onPressed: () {
                        notifier.remove(r.item.id);
                        ref.download(r.item);
                      },
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
        const SizedBox(height: Space.s48),
      ],
    );
  }
}
