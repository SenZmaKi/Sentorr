import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/download_review.dart';
import '../../../player/torrent_lookup.dart';
import '../../../settings/notifier.dart';
import '../../components/adaptive_sheet.dart';
import '../../components/buttons.dart';
import '../../components/progress_track.dart';
import '../../shared/theme/theme.dart';
import '../launch/launch_states.dart';
import 'review_entry.dart';
import 'review_parts.dart';
import 'review_row.dart';

/// The torrents about to download, from the moment Download is pressed:
/// searching, then exact matches counting down, compromises and misses to
/// look at, each item's torrents to change. One item shows its torrent
/// directly; a season lists its episodes. Any touch, scroll or key stops
/// the countdown. Pops itself once the review is confirmed or cancelled.
class ReviewDialog extends ConsumerStatefulWidget {
  const ReviewDialog({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<ReviewDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countdown;
  late final _preferences = torrentPreferencesFor(
    ref.read(settingsProvider).torrents,
  );

  /// The batch item whose torrents are open.
  String? _open;
  bool _counting = false, _spent = false;

  DownloadReviews get _reviews => ref.read(downloadReviewsProvider.notifier);

  @override
  void initState() {
    super.initState();
    _countdown = AnimationController(
      vsync: this,
      duration: ref.read(settingsProvider).torrents.autoActionDelay,
    )..addStatusListener(_onCountdown);
    _sync(_reviews.byId(widget.id));
    ref.listenManual(
      downloadReviewsProvider.select(
        (all) => all.where((r) => r.id == widget.id).firstOrNull,
      ),
      (_, next) {
        if (next == null) return _close();
        setState(() => _sync(next));
      },
    );
  }

  @override
  void dispose() {
    _countdown.dispose();
    super.dispose();
  }

  /// Counts down while every item matches exactly and none is open.
  void _sync(DownloadReview? review) {
    final ready = review != null && review.exact && _open == null;
    if (ready && !_spent && !_counting) {
      _counting = true;
      _countdown.forward(from: 0);
    } else if (!ready && _counting) {
      _counting = false;
      _countdown.stop();
    }
  }

  void _onCountdown(AnimationStatus status) {
    if (status == AnimationStatus.completed && _counting) _confirm();
  }

  void _interrupt() {
    if (_counting) _engage();
  }

  /// The viewer acted on the review: from here they confirm it themselves.
  void _engage() {
    _countdown.stop();
    setState(() {
      _counting = false;
      _spent = true;
    });
  }

  void _confirm() => unawaited(_reviews.confirm(widget.id));

  void _close() {
    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) Navigator.of(context).pop();
  }

  void _openItem(String? id) => setState(() {
    _open = id;
    _sync(_reviews.byId(widget.id));
  });

  @override
  Widget build(BuildContext context) {
    final review = ref.watch(
      downloadReviewsProvider.select(
        (all) => all.where((r) => r.id == widget.id).firstOrNull,
      ),
    );
    if (review == null) return const SizedBox.shrink();
    final single = !review.isSeason && review.entries.length == 1;
    final openId = single ? review.entries.single.item.id : _open;
    final open = openId == null ? null : review.entry(openId);
    final wide =
        open != null && ReviewEntryView.listsAll(open, expanded: !single);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _interrupt(),
      onPointerSignal: (_) => _interrupt(),
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, _) {
          _interrupt();
          return KeyEventResult.ignored;
        },
        child: SheetFrame(
          maxWidth: wide ? 720 : 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReviewHeader(
                subject: reviewSubject(review, open: open),
                heading: _heading(review, open, single: single),
                onBack: open == null || single ? null : () => _openItem(null),
              ),
              if (open == null && review.entries.isNotEmpty) ...[
                const SizedBox(height: Space.s12),
                ReviewSummary(review: review),
              ],
              const SizedBox(height: Space.s16),
              Flexible(child: _body(review, open, single: single)),
              const SizedBox(height: Space.s24),
              if (_counting) ...[
                ProgressTrack(progress: _countdown),
                const SizedBox(height: Space.s16),
              ],
              // Rebuilt as the countdown ticks, for its seconds label.
              AnimatedBuilder(
                animation: _countdown,
                builder: (context, _) => _actions(review, open, single),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(DownloadReview r, ReviewEntry? open, {required bool single}) {
    if (r.error case final error?) return LaunchFailure(error: error);
    if (r.listing) return ReviewBusy('Listing season ${r.season}’s episodes');
    if (r.entries.isEmpty) {
      return Text(
        'Every aired episode of season ${r.season} is already downloaded '
        'or on its way.',
        style: context.type.bodySmall.copyWith(
          color: context.colors.foregroundSecondary,
        ),
      );
    }
    if (open != null) {
      final id = open.item.id;
      return ReviewEntryView(
        key: ValueKey(id),
        entry: open,
        preferences: _preferences,
        expanded: !single,
        onChoose: (torrent) {
          _engage();
          _reviews.choose(widget.id, id, torrent);
        },
        onSearch: (title) {
          _engage();
          unawaited(_reviews.search(widget.id, id, title: title));
        },
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: r.entries.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: context.colors.borderSubtle),
      itemBuilder: (context, i) {
        final e = r.entries[i];
        return ReviewRow(
          entry: e,
          inSeason: r.isSeason,
          onOpen: () {
            _engage();
            _openItem(e.item.id);
          },
          onSkip: (skip) {
            _engage();
            _reviews.skip(widget.id, e.item.id, skipped: skip);
          },
        );
      },
    );
  }

  Widget _actions(DownloadReview r, ReviewEntry? open, bool single) {
    void cancel() => _reviews.cancel(widget.id);
    if (r.error != null && r.isSeason) {
      return ReviewActions(
        onCancel: cancel,
        primary: SButton.primary(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onPressed: () {
            cancel();
            unawaited(_reviews.reviewSeason(r.series!, r.season!));
          },
        ),
      );
    }
    if (!r.listing && r.entries.isEmpty) {
      return ReviewActions(
        onCancel: null,
        primary: SButton.primary(label: 'Close', onPressed: cancel),
      );
    }
    if (open != null && !single) {
      return ReviewActions(
        onCancel: null,
        primary: SButton.primary(
          label: 'Done',
          icon: Icons.check_rounded,
          onPressed: () => _openItem(null),
        ),
      );
    }
    if (r.searching) return ReviewActions(onCancel: cancel);
    final count = r.downloading.length;
    final missing = r.entries.where((e) => e.blocking).length;
    final seconds =
        (_countdown.duration!.inMilliseconds * (1 - _countdown.value) / 1000)
            .ceil();
    final label = _counting
        ? 'Download in ${seconds}s'
        : single || count == 0
        ? 'Download'
        : 'Download $count';
    return ReviewActions(
      onCancel: cancel,
      missing: missing,
      onSkipMissing: missing == 0 || single
          ? null
          : () {
              _engage();
              _reviews.skipMissing(widget.id);
            },
      primary: SButton.primary(
        label: label,
        icon: Icons.download_rounded,
        onPressed: r.blocked || count == 0 ? null : _confirm,
      ),
    );
  }

  String _heading(DownloadReview r, ReviewEntry? open, {required bool single}) {
    if (open != null) {
      if (!single) return 'Choose a torrent';
      return switch (open.status) {
        ReviewStatus.waiting || ReviewStatus.searching => 'Finding a torrent',
        ReviewStatus.ready || ReviewStatus.chosen => 'Ready to download',
        ReviewStatus.close => 'Closest match',
        ReviewStatus.missing =>
          open.error != null
              ? 'Couldn’t search for a torrent'
              : 'Couldn’t find a torrent',
        ReviewStatus.skipped => 'Skipped',
      };
    }
    if (r.error != null) return 'Couldn’t list the episodes';
    if (r.listing) return 'Finding episodes';
    if (r.entries.isEmpty) return 'Nothing left to download';
    if (r.searching) return 'Finding torrents';
    final check = r.entries.where((e) => e.needsChoice).length;
    if (check > 0) return check == 1 ? '1 needs a look' : '$check need a look';
    return 'Ready to download';
  }
}
