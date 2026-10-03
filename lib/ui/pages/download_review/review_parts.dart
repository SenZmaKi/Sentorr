import 'package:flutter/material.dart';

import '../../../library/review_models.dart';
import '../../components/buttons.dart';
import '../../components/cards/card_parts.dart';
import '../../components/progress_track.dart';
import '../../shared/download_actions.dart';
import '../../shared/theme/theme.dart';
import '../../shared/title_format.dart';

/// The subject as a muted eyebrow, then a heading naming the state; a
/// Back control leads when an item's torrents are open within a batch.
class ReviewHeader extends StatelessWidget {
  const ReviewHeader({
    super.key,
    required this.subject,
    required this.heading,
    this.onBack,
  });

  final String subject, heading;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.s4,
      children: [
        Text(
          subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: type.bodySmall.copyWith(color: c.foregroundMuted),
        ),
        Text(heading, style: type.title.copyWith(color: c.foreground)),
      ],
    );
    if (onBack == null) return text;
    return Row(
      children: [
        SIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back to all episodes',
          onPressed: onBack,
        ),
        const SizedBox(width: Space.s8),
        Expanded(child: text),
      ],
    );
  }
}

/// A batch at a glance: how many items, how many are ready or need a
/// look, and roughly how much will download; a track fills as each item
/// is searched.
class ReviewSummary extends StatelessWidget {
  const ReviewSummary({super.key, required this.review});

  final DownloadReview review;

  @override
  Widget build(BuildContext context) {
    final r = review;
    final c = context.colors;
    final count = r.entries.length;
    int where(bool Function(ReviewEntry) test) => r.entries.where(test).length;
    final ready = where(
      (e) => e.status == ReviewStatus.ready || e.status == ReviewStatus.chosen,
    );
    final check = where((e) => e.needsChoice);
    final skipped = where((e) => e.status == ReviewStatus.skipped);
    final searching = r.entries
        .where((e) => e.status == ReviewStatus.searching)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetaLine([
          MetaItem(
            '$count ${r.isSeason ? 'episode' : 'item'}${count == 1 ? '' : 's'}',
            icon: Icons.video_library_outlined,
          ),
          if (ready > 0) MetaItem('$ready ready', icon: Icons.check_rounded),
          if (check > 0)
            MetaItem('$check to check', icon: Icons.info_outline_rounded),
          if (skipped > 0) MetaItem('$skipped skipped'),
          if (r.bytes > 0)
            MetaItem(
              'up to ${sizeLabel(r.bytes)}',
              icon: Icons.save_outlined,
              technical: true,
            ),
        ], style: context.type.bodySmall),
        if (r.searching) ...[
          const SizedBox(height: Space.s12),
          ProgressTrack.value(count == 0 ? 0 : r.settledCount / count),
          const SizedBox(height: Space.s8),
          Text(
            searching == null
                ? 'Searching…'
                : 'Searching for ${itemLabel(searching.item)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.caption.copyWith(color: c.foregroundMuted),
          ),
        ],
      ],
    );
  }
}

/// Work with no item to show yet, e.g. listing a season's episodes.
class ReviewBusy extends StatelessWidget {
  const ReviewBusy(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        SizedBox.square(
          dimension: IconSizes.control,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.action),
        ),
        const SizedBox(width: Space.s12),
        Expanded(
          child: Text(
            text,
            style: context.type.bodySmall.copyWith(
              color: c.foregroundSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cancel and the step forward, with a way past misses when a batch is
/// blocked on them.
class ReviewActions extends StatelessWidget {
  const ReviewActions({
    super.key,
    required this.onCancel,
    this.primary,
    this.onSkipMissing,
    this.missing = 0,
  });

  final VoidCallback? onCancel;
  final SButton? primary;
  final VoidCallback? onSkipMissing;
  final int missing;

  @override
  Widget build(BuildContext context) {
    final skip = onSkipMissing == null
        ? null
        : SButton.ghost(
            label: 'Skip $missing not found',
            icon: Icons.skip_next_rounded,
            onPressed: onSkipMissing,
          );
    final trailing = Wrap(
      alignment: WrapAlignment.end,
      spacing: Space.s8,
      runSpacing: Space.s8,
      children: [
        if (onCancel != null)
          SButton.ghost(label: 'Cancel', onPressed: onCancel),
        ?primary,
      ],
    );
    if (skip == null) return trailing;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.s8,
      runSpacing: Space.s8,
      children: [skip, trailing],
    );
  }
}

/// Names what a review downloads, e.g. `Severance · Season 2` or
/// `Severance · S2 E3 · Episode`.
String reviewSubject(DownloadReview r, {ReviewEntry? open}) {
  final item = open?.item ?? r.entries.singleOrNull?.item;
  if (r.isSeason && open == null) {
    return '${r.series!.title} · Season ${r.season}';
  }
  if (item == null) return '${r.entries.length} downloads';
  final series = item.series;
  if (series == null) {
    final year = item.title.releaseYear;
    return year == null ? item.name : '${item.name} · $year';
  }
  return '${series.title} · ${episodeCode(item.season, item.episode)} · '
      '${item.name}';
}
