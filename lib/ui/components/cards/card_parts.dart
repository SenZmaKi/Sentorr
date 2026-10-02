import 'package:flutter/material.dart';

import '../../shared/theme/theme.dart';

/// Scaled line heights of the text roles cards use, so a row can be sized
/// before its cards are built.
class CardLines {
  const CardLines(this.scaler);

  final TextScaler scaler;

  double get caption => scaler.scale(16);
  double get small => scaler.scale(20);
  double get body => scaler.scale(24);
}

/// One fact in a metadata line: an optional leading icon, and the mono
/// role for numbers people compare (ratings, times, counts).
class MetaItem {
  const MetaItem(this.label, {this.icon, this.leading, this.technical = false});

  final String label;
  final IconData? icon;

  /// Leads the fact in place of [icon], e.g. a site's logo, at the size
  /// the line gives icons.
  final Widget Function(double size)? leading;
  final bool technical;
}

/// Facts on one line, icon-led, separated by spacing rather than dots so
/// each fact reads as its own unit.
class MetaLine extends StatelessWidget {
  const MetaLine(this.items, {super.key, this.color, this.style});

  final List<MetaItem> items;
  final Color? color;

  /// Defaults to caption.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.colors.foregroundMuted;
    final base = (style ?? context.type.caption).copyWith(color: fg);
    final iconSize = (base.fontSize ?? 12) + 2;
    final mono = context.type.technical.copyWith(
      color: fg,
      fontSize: base.fontSize,
      height: base.height,
    );
    // One rich line: facts keep natural widths and only the end ellipsizes,
    // whatever the width or text scale.
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const WidgetSpan(child: SizedBox(width: Space.s12)),
            if (item.leading != null || item.icon != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: Space.s4),
                  child:
                      item.leading?.call(iconSize) ??
                      Icon(item.icon, size: iconSize, color: fg),
                ),
              ),
            TextSpan(text: item.label, style: item.technical ? mono : null),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      // Mono and sans runs differ in ascent and descent; mixed on one line
      // they would grow it past the height cards reserve for it.
      strutStyle: StrutStyle.fromTextStyle(base, forceStrutHeight: true),
    );
  }
}

/// Primary card line.
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.large = false});

  final String text;

  /// Landscape cards use body; posters use label.
  final bool large;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: (large ? context.type.body : context.type.label).copyWith(
      color: context.colors.foreground,
      fontWeight: FontWeight.w600,
    ),
  );
}

/// Small line above a title naming its parent, e.g. an episode's series.
class CardEyebrow extends StatelessWidget {
  const CardEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: context.type.caption.copyWith(
      color: context.colors.foregroundSecondary,
      fontWeight: FontWeight.w500,
    ),
  );
}
