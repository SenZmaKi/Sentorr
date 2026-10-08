import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../lists/mark_watched.dart';
import '../../../shared/errors/error_reports.dart';
import '../../components/buttons.dart';

/// Marks every aired episode of [season] watched, for what the viewer saw
/// elsewhere; shows a check once all of [lastAired] and before is seen.
class SeasonWatchedButton extends ConsumerStatefulWidget {
  const SeasonWatchedButton({
    super.key,
    required this.series,
    required this.season,
    required this.lastAired,
  });

  final ImdbTitle series;
  final int season;

  /// The season's latest aired episode number.
  final int lastAired;

  @override
  ConsumerState<SeasonWatchedButton> createState() =>
      _SeasonWatchedButtonState();
}

class _SeasonWatchedButtonState extends ConsumerState<SeasonWatchedButton> {
  bool _busy = false;

  Future<void> _mark() async {
    setState(() => _busy = true);
    try {
      await ref.read(seasonMarkerProvider).mark(widget.series, widget.season);
    } catch (error, stack) {
      ErrorReports.report(
        "Couldn't mark season ${widget.season} watched",
        error,
        stack,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seen = ref.watch(
      episodeSeenProvider((
        widget.series.id,
        (season: widget.season, episode: widget.lastAired),
      )),
    );
    return SIconButton(
      icon: seen ? Icons.check_circle_rounded : Icons.done_all_rounded,
      tooltip: seen
          ? 'Season ${widget.season} watched'
          : 'Mark season ${widget.season} watched',
      selected: seen,
      onPressed: seen || _busy ? null : _mark,
    );
  }
}
