import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/interactive.dart';
import '../../components/surface.dart';
import '../../shared/theme/theme.dart';
import 'list_sections.dart';

/// The lists down a narrow column, like a library, then New episodes
/// apart from them since it configures rather than lists.
class ListRail extends ConsumerWidget {
  const ListRail({super.key});

  /// Matches the Settings sidebar on wide windows.
  static const width = 240.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(listsSectionProvider);
    final counts = ref.watch(sectionCountsProvider);
    Widget item(ListsSection s) => _RailItem(
      section: s,
      count: counts[s]!,
      selected: s == current,
      onTap: () => ref.read(listsSectionProvider.notifier).pick(s),
    );
    return Column(
      spacing: Space.s4,
      children: [
        for (final s in ListsSection.values)
          if (s.status != null) item(s),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.s8),
          child: Divider(
            height: 1,
            thickness: 1,
            color: context.colors.borderSubtle,
          ),
        ),
        item(ListsSection.newEpisodes),
      ],
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.section,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final ListsSection section;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final raised = context.depth.of(SurfaceDepth.raised);
    return Interactive(
      onTap: onTap,
      selected: selected,
      semanticLabel: '${section.label}, $count',
      borderRadius: Radii.control,
      builder: (context, s) {
        final fg = selected || s.hovered ? c.foreground : c.foregroundSecondary;
        return DepthBox(
          style: selected
              ? raised
              : DepthStyle(fill: s.hovered ? c.stateHover : raised.fill.clear),
          radius: Radii.control,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: Space.s12),
          child: Row(
            children: [
              Icon(section.icon, size: IconSizes.control, color: fg),
              const SizedBox(width: Space.s12),
              Expanded(
                child: Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.label.copyWith(color: fg),
                ),
              ),
              if (count > 0)
                Text(
                  '$count',
                  style: context.type.technical.copyWith(
                    color: c.foregroundMuted,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
