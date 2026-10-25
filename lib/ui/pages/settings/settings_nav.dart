import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../components/interactive.dart';
import '../../components/motion.dart';
import '../../components/surface.dart';
import '../../shared/theme/theme.dart';
import 'settings_category.dart';

/// Category list under area headings. As a sidebar the active category is
/// filled and marked with a bar; on narrow layouts each row is a raised card
/// that opens its page.
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
    final gap = sidebar ? Space.s4 : Space.s8;
    SettingsArea? area;
    final children = <Widget>[];
    double lineHeight(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: 'Ag', style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final rowHeight =
        math.max(
          math.max(lineHeight(context.type.label), IconSizes.control),
          Space.s16,
        ) +
        Space.s8 * 2;
    final headingHeight = lineHeight(context.type.caption) + Space.s8;
    var top = 0.0;
    double? selectedTop;
    for (final c in SettingsCategory.available) {
      if (c.area != area) {
        top += headingHeight + (children.isEmpty ? 0 : Space.s24);
        area = c.area;
        children.add(_AreaLabel(area, first: children.isEmpty, inset: sidebar));
      } else {
        children.add(SizedBox(height: gap));
        top += gap;
      }
      if (c == active) selectedTop = top;
      top += rowHeight;
      children.add(
        sidebar
            ? _SidebarItem(c, c == active, onSelect)
            : _CardItem(c, onSelect),
      );
    }
    final items = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (!sidebar) return items;
    return Stack(
      children: [
        AnimatedPositioned(
          duration: reduceMotion(context) ? Duration.zero : Motion.reveal,
          curve: Motion.change,
          top: selectedTop ?? 0,
          left: 0,
          right: 0,
          height: rowHeight,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: selectedTop == null ? 0 : 1,
              duration: reduceMotion(context) ? Duration.zero : Motion.reveal,
              child: DepthBox(
                style: context.depth.of(SurfaceDepth.raised),
                radius: Radii.control,
                padding: const EdgeInsets.only(left: Space.s12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: Borders.focus,
                    height: Space.s16,
                    decoration: BoxDecoration(
                      color: context.colors.foreground,
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        items,
      ],
    );
  }
}

/// Names the categories below it; later areas keep a wider gap above.
class _AreaLabel extends StatelessWidget {
  const _AreaLabel(this.area, {required this.first, required this.inset});

  final SettingsArea area;
  final bool first;

  /// Lines the label up with sidebar item text rather than the edge.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          inset ? Space.s12 : Space.s4,
          first ? 0 : Space.s24,
          0,
          Space.s8,
        ),
        child: Text(
          area.label,
          style: context.type.caption.copyWith(
            color: context.colors.foregroundMuted,
          ),
        ),
      ),
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
          color: !selected && s.hovered ? c.stateHover : c.stateHover.clear,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          children: [
            const SizedBox(width: Borders.focus, height: Space.s16),
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
