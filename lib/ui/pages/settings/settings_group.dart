import 'package:flutter/material.dart';

import '../../components/interactive.dart';
import '../../components/surface.dart';
import '../../shared/theme/theme.dart';
import 'settings_search.dart';

/// A titled group of settings on a raised surface, rows divided by fine
/// rules. Under a search it keeps only matching rows, or every row when
/// its title or keywords match, and disappears when nothing does. Among
/// results from many categories it names its category above its title.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    this.description,
    this.keywords = '',
    this.trailing,
    required this.children,
  });

  final String title;

  /// What the group's settings share; shown, not searched, so a word in it
  /// doesn't pull in every row.
  final String? description;
  final String keywords;
  final Widget? trailing;

  /// Rows; those that are [SettingsSearchable] filter under a search.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scope = SettingsQuery.of(context);
    final search = scope?.search;
    final whole = search == null || search.matches([title, keywords]);
    final rows = [
      for (final child in children)
        if (whole ||
            (child is SettingsSearchable &&
                (child as SettingsSearchable).matches(search)))
          child,
    ];
    scope?.hits?.report(context, rows.isNotEmpty);
    if (rows.isEmpty) return const SizedBox.shrink();
    final category = scope?.category;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s24),
      child: Surface(
        depth: SurfaceDepth.raised,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.s16,
                Space.s16,
                Space.s16,
                Space.s12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (category != null)
                          _CategoryLink(category, scope?.onOpenCategory),
                        Text(
                          title,
                          style: context.type.label.copyWith(
                            color: c.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (description != null)
                          Text(
                            description!,
                            style: context.type.bodySmall.copyWith(
                              color: c.foregroundSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            for (final row in rows) ...[
              Divider(height: 1, thickness: 1, color: c.borderSubtle),
              row,
            ],
          ],
        ),
      ),
    );
  }
}

/// The category a search result belongs to, opening it on its own page.
class _CategoryLink extends StatelessWidget {
  const _CategoryLink(this.category, this.onOpen);

  final String category;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s4),
      child: Interactive(
        onTap: onOpen,
        semanticLabel: 'Open $category',
        builder: (context, s) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category,
              style: context.type.caption.copyWith(
                color: s.hovered ? c.foreground : c.foregroundMuted,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: IconSizes.metadata,
              color: s.hovered ? c.foreground : c.foregroundMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// One setting: what it is, what it does now, and its control. Narrow
/// rows put the control under the text.
class SettingsTile extends StatelessWidget implements SettingsSearchable {
  const SettingsTile({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.keywords = '',
    this.trailing,
    this.below,
    this.enabled = true,
  });

  final IconData? icon;

  /// Replaces [icon], e.g. a site's logo.
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String keywords;
  final Widget? trailing;

  /// Extra detail under the subtitle, e.g. a folder path.
  final Widget? below;
  final bool enabled;

  @override
  bool matches(SettingsSearch? search) =>
      search == null || search.matches([title, ?subtitle, keywords]);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lead =
        leading ??
        (icon == null
            ? null
            : Icon(icon, size: IconSizes.control, color: c.foregroundMuted));
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.type.label.copyWith(color: c.foreground)),
        if (subtitle != null)
          Text(
            subtitle!,
            style: context.type.bodySmall.copyWith(
              color: c.foregroundSecondary,
            ),
          ),
        if (below != null) ...[const SizedBox(height: Space.s4), below!],
      ],
    );
    return Opacity(
      opacity: enabled ? 1 : .55,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.s16,
          vertical: Space.s12,
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final stacked = box.maxWidth < 520 && trailing != null;
            final head = Row(
              children: [
                if (lead != null) ...[lead, const SizedBox(width: Space.s12)],
                Expanded(child: text),
                if (trailing != null && !stacked) ...[
                  const SizedBox(width: Space.s16),
                  trailing!,
                ],
              ],
            );
            if (!stacked) return head;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                head,
                const SizedBox(height: Space.s12),
                Padding(
                  padding: EdgeInsets.only(
                    left: lead == null ? 0 : IconSizes.control + Space.s12,
                  ),
                  child: trailing!,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
