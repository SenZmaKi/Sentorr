import 'package:flutter/material.dart';

import '../../components/interactive.dart';
import '../../components/surface.dart';
import '../../shared/theme/theme.dart';
import 'settings_category.dart';

/// Category list. As a sidebar the active category is filled and marked
/// with a bar; on narrow layouts each row is a raised card that opens its
/// page.
class SettingsNav extends StatelessWidget {
  const SettingsNav({
    super.key,
    required this.onSelect,
    this.active,
    this.sidebar = true,
  });

  final SettingsCategory? active;
  final ValueChanged<SettingsCategory> onSelect;
  final bool sidebar;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final c in SettingsCategory.available)
        sidebar
            ? _SidebarItem(c, c == active, onSelect)
            : _CardItem(c, onSelect),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) SizedBox(height: sidebar ? Space.s4 : Space.s8),
          item,
        ],
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem(this.category, this.selected, this.onSelect);

  final SettingsCategory category;
  final bool selected;
  final ValueChanged<SettingsCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Interactive(
      onTap: () => onSelect(category),
      selected: selected,
      semanticLabel: category.title,
      builder: (context, s) => AnimatedContainer(
        duration: Motion.hover,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s12,
          vertical: Space.s8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? c.selection
              : s.hovered
              ? c.stateHover
              : c.stateHover.clear,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Motion.hover,
              width: Borders.focus,
              height: Space.s16,
              decoration: BoxDecoration(
                color: selected ? c.foreground : c.foreground.clear,
                borderRadius: BorderRadius.circular(Radii.full),
              ),
            ),
            const SizedBox(width: Space.s8),
            Icon(
              category.icon,
              size: IconSizes.control,
              color: selected ? c.foreground : c.foregroundMuted,
            ),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Text(
                category.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.label.copyWith(
                  color: selected || s.hovered
                      ? c.foreground
                      : c.foregroundSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardItem extends StatelessWidget {
  const _CardItem(this.category, this.onSelect);

  final SettingsCategory category;
  final ValueChanged<SettingsCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Interactive(
      onTap: () => onSelect(category),
      semanticLabel: category.title,
      borderRadius: Radii.card,
      builder: (context, s) => DepthBox(
        style: s.hovered
            ? context.depth.of(SurfaceDepth.raised).hovered()
            : context.depth.of(SurfaceDepth.raised),
        radius: Radii.card,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s16,
          vertical: Space.s12,
        ),
        child: Row(
          children: [
            Icon(category.icon, size: IconSizes.control, color: c.foreground),
            const SizedBox(width: Space.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: context.type.label.copyWith(color: c.foreground),
                  ),
                  Text(
                    category.subtitle,
                    style: context.type.bodySmall.copyWith(
                      color: c.foregroundSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: IconSizes.control,
              color: c.foregroundMuted,
            ),
          ],
        ),
      ),
    );
  }
}
