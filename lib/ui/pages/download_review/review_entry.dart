import 'package:flutter/material.dart';

import '../../../library/review_models.dart';
import '../../../player/torrent_lookup.dart';
import '../../../torrents/resolution_models.dart';
import '../../components/buttons.dart';
import '../../shared/theme/theme.dart';
import '../launch/launch_states.dart';
import '../torrent_picker/torrent_option.dart';
import '../torrent_picker/torrent_picker.dart';

/// The torrent one item downloads from, and the others to choose instead:
/// searching, the choice with Show N more, every option, or a miss to
/// search again. Choosing applies at once; the host owns confirming.
class ReviewEntryView extends StatefulWidget {
  const ReviewEntryView({
    super.key,
    required this.entry,
    required this.preferences,
    required this.onChoose,
    required this.onSearch,
    this.expanded = false,
  });

  final ReviewEntry entry;
  final TorrentPreferences preferences;
  final ValueChanged<TorrentCandidate> onChoose;

  /// Searches again, under another title when one is given.
  final ValueChanged<String?> onSearch;

  /// Lists every option from the start, e.g. when the viewer opened the
  /// item to change it.
  final bool expanded;

  /// Whether this content lists every option, and so needs a wider sheet.
  static bool listsAll(ReviewEntry entry, {required bool expanded}) =>
      (expanded || entry.status == ReviewStatus.close) &&
      (entry.resolution?.candidates.isNotEmpty ?? false);

  @override
  State<ReviewEntryView> createState() => _ReviewEntryViewState();
}

class _ReviewEntryViewState extends State<ReviewEntryView> {
  late final _title = TextEditingController(
    text: widget.entry.title ?? _defaultTitle,
  );
  late bool _showAll = ReviewEntryView.listsAll(
    widget.entry,
    expanded: widget.expanded,
  );

  String get _defaultTitle {
    final item = widget.entry.item;
    return item.series?.title ?? item.name;
  }

  @override
  void didUpdateWidget(ReviewEntryView old) {
    super.didUpdateWidget(old);
    // A fresh search result lists everything when it is a compromise.
    if (!identical(old.entry.resolution, widget.entry.resolution) &&
        widget.entry.status == ReviewStatus.close) {
      _showAll = true;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _search() => widget.onSearch(
    _title.text.trim() == _defaultTitle ? null : _title.text.trim(),
  );

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final c = context.colors;
    final type = context.type;
    if (!e.settled) {
      return LaunchSearching(searchText: _searchText(e));
    }
    if (e.error case final error?) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LaunchFailure(error: error),
            const SizedBox(height: Space.s16),
            Align(
              alignment: Alignment.centerLeft,
              child: SButton(
                label: 'Search again',
                icon: Icons.refresh_rounded,
                onPressed: () => widget.onSearch(e.title),
              ),
            ),
          ],
        ),
      );
    }
    final resolution = e.resolution;
    final torrent = e.torrent;
    if (torrent == null) {
      return SingleChildScrollView(
        child: resolution == null
            ? const SizedBox.shrink()
            : LaunchMiss(
                resolution: resolution,
                controller: _title,
                onSearch: _search,
              ),
      );
    }
    final all = resolution?.candidates ?? const <TorrentCandidate>[];
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          e.fromPack && resolution == null
              ? 'Shares the season torrent found for an earlier episode; '
                    'only this episode’s file is kept.'
              : resolution?.message ?? '',
          style: type.bodySmall.copyWith(color: c.foregroundSecondary),
        ),
        if (e.status == ReviewStatus.close) ...[
          const SizedBox(height: Space.s12),
          LaunchNote([
            for (final concern in e.concerns)
              concern.describe(widget.preferences),
            'Download the closest match, or choose another torrent.',
          ]),
        ],
        const SizedBox(height: Space.s12),
        if (_showAll && all.isNotEmpty)
          Flexible(
            child: TorrentPicker(
              candidates: all,
              selected: torrent,
              onSelected: widget.onChoose,
              title: _title,
              onSearch: (_) => _search(),
            ),
          )
        else ...[
          TorrentOption(
            candidate: torrent,
            best: identical(torrent, all.firstOrNull),
            selected: true,
            onTap: () {},
          ),
          const SizedBox(height: Space.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: all.length > 1
                ? SButton.ghost(
                    label: 'Show ${all.length - 1} more',
                    icon: Icons.expand_more_rounded,
                    onPressed: () => setState(() => _showAll = true),
                  )
                : all.isEmpty
                ? SButton.ghost(
                    label: 'Find other torrents',
                    icon: Icons.search_rounded,
                    onPressed: () => widget.onSearch(e.title),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
    // The picker scrolls itself; a single choice scrolls here.
    return _showAll && all.isNotEmpty
        ? body
        : SingleChildScrollView(child: body);
  }

  String? _searchText(ReviewEntry e) {
    try {
      return torrentQueryFor(e.item, title: e.title).searchText;
    } on FormatException {
      return null;
    }
  }
}
