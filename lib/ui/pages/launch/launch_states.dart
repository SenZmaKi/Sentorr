import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../torrents/resolution_models.dart';
import '../../components/buttons.dart';
import '../../components/inputs.dart';
import '../../shared/theme/theme.dart';

/// While the sources are searched: what is being looked for.
class LaunchSearching extends StatelessWidget {
  const LaunchSearching({super.key, this.searchText});

  /// Null while the item itself is still being found.
  final String? searchText;

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
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Searching for '),
                TextSpan(
                  text: searchText ?? 'the first episode',
                  style: searchText == null ? null : context.type.technical,
                ),
              ],
            ),
            style: context.type.bodySmall.copyWith(
              color: c.foregroundSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// No torrent was eligible: why, what might help, and a search under
/// another title. Submitting the field searches again.
class LaunchMiss extends StatelessWidget {
  const LaunchMiss({
    super.key,
    required this.resolution,
    required this.controller,
    required this.onSearch,
  });

  final TorrentResolution resolution;
  final TextEditingController controller;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = context.type;
    final tips = resolution.recoverySuggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          resolution.message,
          style: type.bodySmall.copyWith(color: c.foregroundSecondary),
        ),
        if (tips.isNotEmpty) ...[
          const SizedBox(height: Space.s12),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: Space.s2),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: IconSizes.metadata,
                      color: c.foregroundMuted,
                    ),
                  ),
                  const SizedBox(width: Space.s8),
                  Expanded(
                    child: Text(
                      tip,
                      style: type.bodySmall.copyWith(color: c.foregroundMuted),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: Space.s24),
        Text(
          'Search under another title',
          style: type.label.copyWith(color: c.foreground),
        ),
        const SizedBox(height: Space.s8),
        STextField(
          controller: controller,
          semanticLabel: 'Title to search for',
          prefixIcon: Icons.search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearch(),
        ),
      ],
    );
  }
}

/// Playback could not be prepared at all, e.g. the episode list failed.
class LaunchFailure extends StatelessWidget {
  const LaunchFailure({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: IconSizes.control, color: c.error),
        const SizedBox(width: Space.s8),
        Expanded(
          child: Text(
            failureMessage(error),
            style: context.type.bodySmall.copyWith(color: c.foreground),
          ),
        ),
      ],
    );
  }
}

String failureMessage(Object error) => switch (error) {
  FormatException(:final message) => message,
  DioException() => 'Couldn’t reach the network. Check your connection.',
  _ => 'Something went wrong while preparing playback.',
};

/// A compromise the viewer should know about before playing: warning text
/// on its paired surface, led by an icon so color is not the only cue.
class LaunchNote extends StatelessWidget {
  const LaunchNote(this.lines, {super.key});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.warningSurface,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: IconSizes.control,
              color: c.warning,
            ),
            const SizedBox(width: Space.s8),
            Expanded(
              child: Text(
                lines.join(' '),
                style: context.type.bodySmall.copyWith(color: c.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cancel and the step forward, the forward one dominant.
class LaunchActions extends StatelessWidget {
  const LaunchActions({super.key, required this.onCancel, this.primary});

  final VoidCallback onCancel;
  final SButton? primary;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    spacing: Space.s8,
    runSpacing: Space.s8,
    children: [
      SButton.ghost(label: 'Cancel', onPressed: onCancel),
      ?primary,
    ],
  );
}
