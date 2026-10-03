import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'adaptive_menu.dart';
import 'surface.dart';

export 'adaptive_menu.dart' show AdaptiveMenuController;

/// One choice in an [ActionMenu].
class MenuAction {
  const MenuAction(
    this.label, {
    required this.onPressed,
    this.icon,
    this.checked,
    this.destructive = false,
    this.stayOpen,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  /// A toggle's state, shown as a check; null for plain commands.
  final bool? checked;

  /// Error foreground, for actions that remove something.
  final bool destructive;

  /// Overrides [staysOpen], e.g. a single-choice list with checks.
  final bool? stayOpen;

  /// Whether choosing it leaves the menu open; toggles do by default.
  bool get staysOpen => stayOpen ?? checked != null;
}

/// A menu of [actions] opened from the control [builder] draws; toggles
/// stay open so several can change. Floats beside its control, or rises as
/// a bottom sheet on a touch phone ([AdaptiveMenu]).
class ActionMenu extends StatelessWidget {
  const ActionMenu({
    super.key,
    required this.actions,
    required this.builder,
    this.title,
  });

  final List<MenuAction> actions;
  final Widget Function(BuildContext context, AdaptiveMenuController menu)
  builder;

  /// Heads the bottom sheet form.
  final String? title;

  @override
  Widget build(BuildContext context) =>
      AdaptiveMenu(entries: actions, title: title, builder: builder);
}

/// Room around a menu for its floating shadow, which the menu's own scroll
/// viewport would otherwise clip.
const menuBleed = Space.s16;

/// MenuAnchor's own chrome off: [MenuPanel] draws the surface.
const menuAnchorStyle = MenuStyle(
  backgroundColor: WidgetStatePropertyAll(Colors.transparent),
  shadowColor: WidgetStatePropertyAll(Colors.transparent),
  surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
  elevation: WidgetStatePropertyAll(0),
  padding: WidgetStatePropertyAll(EdgeInsets.zero),
);

/// A row in a floating menu: a check or icon, then its label.
class MenuOption extends StatelessWidget {
  const MenuOption({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.checked,
    this.destructive = false,
    this.closeOnActivate = true,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool? checked;
  final bool destructive;
  final bool closeOnActivate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = destructive ? c.error : c.foreground;
    WidgetStateProperty<V> by<V>(V Function(Set<WidgetState> s) f) =>
        WidgetStateProperty.resolveWith(f);
    final selected = checked ?? false;
    return MenuItemButton(
      onPressed: onPressed,
      closeOnActivate: closeOnActivate,
      // Hover alone must not draw the keyboard focus ring.
      requestFocusOnHover: false,
      leadingIcon: SizedBox.square(
        dimension: IconSizes.metadata,
        child: selected || icon != null
            ? Icon(
                selected ? Icons.check_rounded : icon,
                size: IconSizes.metadata,
                color: fg,
              )
            : null,
      ),
      style: ButtonStyle(
        backgroundColor: by(
          (s) => s.contains(WidgetState.pressed)
              ? destructive
                    ? c.errorSurface
                    : c.statePressed
              : s.contains(WidgetState.hovered)
              ? destructive
                    ? c.errorSurface
                    : c.stateHover
              : selected && icon == null
              ? c.selection
              : c.stateHover.clear,
        ),
        foregroundColor: WidgetStatePropertyAll(fg),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        textStyle: WidgetStatePropertyAll(context.type.bodySmall),
        minimumSize: WidgetStatePropertyAll(Size(0, context.density.menuRow)),
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
      child: Text(label, style: TextStyle(color: fg)),
    );
  }
}

/// The floating surface menus draw their options on.
class MenuPanel extends StatelessWidget {
  const MenuPanel({super.key, required this.minWidth, required this.children});

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
