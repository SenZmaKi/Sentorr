import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../following/tracked.dart';
import '../../../lists/models.dart';
import '../../../lists/notifier.dart';
import '../../components/navigation.dart';
import '../../shared/title_icons.dart';

/// What the Lists page shows: one of the lists, or the new-episode
/// switches for the series being watched.
enum ListsSection {
  watching(WatchStatus.watching),
  rewatching(WatchStatus.rewatching),
  planned(WatchStatus.planned),
  paused(WatchStatus.paused),
  dropped(WatchStatus.dropped),
  completed(WatchStatus.completed),
  newEpisodes(null);

  const ListsSection(this.status);

  /// Null for [newEpisodes].
  final WatchStatus? status;

  static ListsSection of(WatchStatus status) =>
      values.firstWhere((s) => s.status == status);

  String get label => status?.label ?? 'New episodes';
  IconData get icon =>
      status == null ? Icons.notifications_outlined : statusIcon(status!);
}

/// The section the viewer is looking at; kept while they browse elsewhere.
final listsSectionProvider =
    NotifierProvider<ListsSectionNotifier, ListsSection>(
      ListsSectionNotifier.new,
    );

class ListsSectionNotifier extends Notifier<ListsSection> {
  @override
  ListsSection build() => ListsSection.watching;

  void pick(ListsSection section) => state = section;
}

/// How many titles each section holds; New episodes counts series.
final sectionCountsProvider = Provider<Map<ListsSection, int>>((ref) {
  final counts = {for (final s in ListsSection.values) s: 0};
  for (final e in ref.watch(watchListsProvider)) {
    final section = ListsSection.of(e.status!);
    counts[section] = counts[section]! + 1;
  }
  counts[ListsSection.newEpisodes] = ref.watch(trackedSeriesProvider).length;
  return counts;
});

/// The sections as tabs, for windows too narrow for the rail. They outgrow
/// a phone, so the row scrolls rather than squeezes.
class ListTabs extends ConsumerWidget {
  const ListTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(sectionCountsProvider);
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedTabs(
          value: ref.watch(listsSectionProvider),
          segments: {
            for (final s in ListsSection.values)
              s: counts[s] == 0 ? s.label : '${s.label}  ${counts[s]}',
          },
          onChanged: ref.read(listsSectionProvider.notifier).pick,
        ),
      ),
    );
  }
}
