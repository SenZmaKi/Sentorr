import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../lists/mark_watched.dart';
import '../../../shared/errors/error_reports.dart';
import '../../components/buttons.dart';

/// Marks a season watched or clears its watched status.
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

  Future<void> _mark(bool seen) async {
    setState(() => _busy = true);
    try {
      final marker = ref.read(seasonMarkerProvider);
      if (seen) {
        await marker.unmark(widget.series, widget.season);
      } else {
        await marker.mark(widget.series, widget.season);
      }
    } catch (error, stack) {
      ErrorReports.report(
        "Couldn't mark season ${widget.season} ${seen ? 'unwatched' : 'watched'}",
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
      icon: seen ? Icons.remove_done_rounded : Icons.done_all_rounded,
      tooltip: seen
          ? 'Mark season ${widget.season} unwatched'
          : 'Mark season ${widget.season} watched',
      selected: seen,
      onPressed: _busy ? null : () => _mark(seen),
    );
  }
}
