import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'interactive.dart';
import 'surface.dart';

/// Dropdown in the input contract: a raised trigger showing the choice, and
/// a floating menu where chosen options carry a check. [multiple] keeps the
/// menu open so several options can be toggled.
class SSelect<T> extends StatelessWidget {
  const SSelect({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    this.optionLabelOf,
    required this.onSelected,
    required this.semanticLabel,
    this.multiple = false,
    this.onClear,
    this.placeholder = 'Any',
    this.icon,
  });

  final List<T> options;
  final Set<T> selected;
  final String Function(T option) labelOf;

  /// The menu's wording when it says more than the trigger, e.g. a count.
  final String Function(T option)? optionLabelOf;

  /// Single selection picks; [multiple] toggles.
  final ValueChanged<T> onSelected;
  final String semanticLabel;
  final bool multiple;

  /// Adds a leading [placeholder] option that clears the selection.
  final VoidCallback? onClear;
  final String placeholder;
  final IconData? icon;

  // Room around the menu for its floating shadow, which the menu's own
  // scroll viewport would otherwise clip.
  static const _bleed = Space.s16;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chosen = [
      for (final o in options)
        if (selected.contains(o)) labelOf(o),
    ];
    final value = chosen.isEmpty ? null : chosen.join(', ');
    return LayoutBuilder(
      builder: (context, box) => MenuAnchor(
        alignmentOffset: const Offset(-_bleed, Space.s4 - _bleed),
        style: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          shadowColor: WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          elevation: WidgetStatePropertyAll(0),
          padding: WidgetStatePropertyAll(EdgeInsets.zero),
        ),
        menuChildren: [
          Padding(
            padding: const EdgeInsets.all(_bleed),
            child: _MenuPanel(
              minWidth: box.hasBoundedWidth ? box.maxWidth : 0,
              children: [
                if (onClear != null)
                  _option(
                    context,
                    placeholder,
                    checked: selected.isEmpty,
                    onPressed: onClear!,
                  ),
                for (final o in options)
                  _option(
                    context,
                    (optionLabelOf ?? labelOf)(o),
                    checked: selected.contains(o),
                    onPressed: () => onSelected(o),
                  ),
              ],
            ),
          ),
        ],
        builder: (context, menu, _) => Interactive(
          onTap: () => menu.isOpen ? menu.close() : menu.open(),
          semanticLabel: '$semanticLabel: ${value ?? placeholder}',
          builder: (context, s) => DepthBox(
            style: s.hovered
                ? context.depth.of(SurfaceDepth.raised).hovered()
                : context.depth.of(SurfaceDepth.raised),
            radius: Radii.control,
            height: ControlHeights.standard,
            border: Border.all(
              color: menu.isOpen ? c.focus : c.borderControl,
              width: menu.isOpen ? Borders.focus : Borders.edge,
            ),
            padding: const EdgeInsets.symmetric(horizontal: Space.s12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: IconSizes.metadata,
                    color: c.foregroundMuted,
                  ),
                  const SizedBox(width: Space.s8),
                ],
                Flexible(
                  fit: box.hasBoundedWidth ? FlexFit.tight : FlexFit.loose,
                  child: Text(
                    value ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodySmall.copyWith(
                      color: value == null ? c.foregroundMuted : c.foreground,
                    ),
                  ),
                ),
                const SizedBox(width: Space.s8),
                Icon(
                  Icons.unfold_more_rounded,
                  size: IconSizes.metadata,
                  color: c.foregroundMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context,
    String label, {
    required bool checked,
    required VoidCallback onPressed,
  }) {
    final c = context.colors;
    WidgetStateProperty<V> by<V>(V Function(Set<WidgetState> s) f) =>
        WidgetStateProperty.resolveWith(f);
    return MenuItemButton(
      onPressed: onPressed,
      closeOnActivate: !multiple,
      // Hover alone must not draw the keyboard focus ring.
      requestFocusOnHover: false,
      leadingIcon: SizedBox.square(
        dimension: IconSizes.metadata,
        child: checked
            ? Icon(
                Icons.check_rounded,
                size: IconSizes.metadata,
                color: c.foreground,
              )
            : null,
      ),
      style: ButtonStyle(
        backgroundColor: by(
          (s) => s.contains(WidgetState.pressed)
              ? c.statePressed
              : s.contains(WidgetState.hovered)
              ? c.stateHover
              : checked
              ? c.selection
              : c.stateHover.clear,
        ),
        foregroundColor: WidgetStatePropertyAll(c.foreground),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        textStyle: WidgetStatePropertyAll(context.type.bodySmall),
        minimumSize: const WidgetStatePropertyAll(
          Size(0, ControlHeights.compact),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Space.s8),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(Radii.chip)),
          ),
        ),
        side: by(
          (s) => s.contains(WidgetState.focused)
              ? BorderSide(color: c.focus, width: Borders.focus)
              : BorderSide.none,
        ),
      ),
      child: Text(label, style: TextStyle(color: c.foreground)),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.minWidth, required this.children});

  final double minWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DepthBox(
    style: context.depth.of(SurfaceDepth.floating),
    radius: Radii.control,
    border: Border.all(color: context.colors.borderStrong),
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxHeight: 360),
      child: SingleChildScrollView(
        // The menu already sits in a scroll view of its own.
        primary: false,
        padding: const EdgeInsets.all(Space.s8),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}
