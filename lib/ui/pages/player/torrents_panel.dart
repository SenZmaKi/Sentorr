import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../player/models.dart';
import '../../../player/stream/torrent_playback.dart';
import '../../../player/torrent_search.dart';
import '../../../torrents/resolution_models.dart';
import '../../components/buttons.dart';
import '../../components/dialog_actions.dart';
import '../../components/section_header.dart';
import '../../shared/theme/theme.dart';
import '../launch/launch_states.dart';
import '../torrent_picker/torrent_picker.dart';
import 'menu_rows.dart';

/// The torrents found for what is playing, beside the picture, to switch
/// to another. Marks the one streaming and any that failed. Searching under
/// another title replaces the list until the panel closes.
class TorrentsPanel extends ConsumerStatefulWidget {
  const TorrentsPanel({
    super.key,
    required this.item,
    required this.status,
    required this.onSwitch,
    required this.onClose,
  });

  final PlaybackItem item;
  final ValueListenable<StreamStatus?> status;
  final void Function(TorrentCandidate torrent, TorrentResolution? options)
  onSwitch;
  final VoidCallback onClose;

  @override
  ConsumerState<TorrentsPanel> createState() => _TorrentsPanelState();
}

class _TorrentsPanelState extends ConsumerState<TorrentsPanel> {
  late final _title = TextEditingController(
    text: widget.item.series?.title ?? widget.item.name,
  );
  CancelToken? _cancel;
  TorrentCandidate? _selected;

  /// A search run from here; replaces the stream's list while set.
  TorrentResolution? _searched;
  bool _searching = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // An item opened from a remembered torrent has no list to offer yet.
    if (widget.status.value?.options == null) _search(null);
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _title.dispose();
    super.dispose();
  }

  Future<void> _search(String? title) async {
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    setState(() {
      _searching = true;
      _error = null;
    });
    final name = title?.trim();
    try {
      final found = await ref.read(torrentSearchProvider)(
        widget.item,
        title: name == null || name.isEmpty ? null : name,
        cancel: cancel,
      );
      if (!mounted || cancel != _cancel) return;
      setState(() {
        _searched = found;
        _searching = false;
        _selected = null;
      });
    } catch (error) {
      if (!mounted ||
          cancel != _cancel ||
          (error is DioException && CancelToken.isCancel(error))) {
        return;
      }
      setState(() {
        _error = error;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sized by the player's panel slot.
    return PlayerMenuSurface(
      padding: const EdgeInsets.all(Space.s16),
      child: ValueListenableBuilder(
        valueListenable: widget.status,
        builder: (context, status, _) {
          final options = _searched ?? status?.options;
          final playing = status?.stage == StreamStage.streaming
              ? status?.torrent
              : null;
          final selected = _selected;
          final count = options?.candidates.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                icon: Icons.swap_horiz_rounded,
                title: 'Torrents',
                subtitle: playing == null
                    ? 'Choose what to stream from'
                    : 'Switch without losing your place',
                count: count == null ? null : '$count found',
                action: SIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close (t)',
                  onPressed: widget.onClose,
                ),
              ),
              const SizedBox(height: Space.s16),
              Expanded(child: _body(status, options)),
              const SizedBox(height: Space.s16),
              DialogActions(
                children: [
                  SButton.ghost(label: 'Cancel', onPressed: widget.onClose),
                  SButton.primary(
                    label: 'Stream this torrent',
                    icon: Icons.play_arrow_rounded,
                    onPressed:
                        selected == null ||
                            selected.release.infoHash ==
                                playing?.release.infoHash
                        ? null
                        : () => widget.onSwitch(selected, _searched),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _body(StreamStatus? status, TorrentResolution? options) {
    if (_searching) {
      return Align(
        alignment: Alignment.topLeft,
        child: LaunchSearching(searchText: _title.text),
      );
    }
    if (_error case final error?) {
      return Align(
        alignment: Alignment.topLeft,
        child: LaunchFailure(error: error),
      );
    }
    if (options == null) return const SizedBox.shrink();
    if (options.candidates.isEmpty) {
      return SingleChildScrollView(
        child: LaunchMiss(
          resolution: options,
          controller: _title,
          onSearch: () => unawaited(_search(_title.text)),
        ),
      );
    }
    return TorrentPicker(
      candidates: options.candidates,
      selected: _selected,
      onSelected: (c) => setState(() => _selected = c),
      playing: status?.stage == StreamStage.streaming
          ? status?.torrent?.release.infoHash
          : null,
      failed: _searched == null ? status?.failed ?? const {} : const {},
      title: _title,
      onSearch: (title) => unawaited(_search(title)),
    );
  }
}
