import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../shared/layout/adaptive.dart';
import '../shared/theme/theme.dart';
import 'adaptive_sheet.dart';
import 'buttons.dart';
import 'menu.dart';

/// Opens and closes an [AdaptiveMenu], whichever form it takes.
abstract interface class AdaptiveMenuController {
  bool get isOpen;
  void open();
  void close();
}

/// A menu of [entries] opened from the control [builder] draws. With a
/// pointer, or wherever there is room, it floats beside its control; on a
/// touch phone it rises as a bottom sheet list with full-height rows (and
/// Done when choices stay open). Entries follow [MenuAction]: toggles keep
/// the menu open unless they say otherwise.
class AdaptiveMenu extends StatefulWidget {
  const AdaptiveMenu({
    super.key,
    required this.entries,
    required this.builder,
    this.minWidth = 200,
    this.matchAnchorWidth = false,
    this.title,
  });

  final List<MenuAction> entries;
  final Widget Function(BuildContext context, AdaptiveMenuController menu)
  builder;

  /// The floating menu's least width.
  final double minWidth;

  /// The floating menu is at least as wide as its control, as a select's.
  final bool matchAnchorWidth;

  /// Heads the bottom sheet, saying what is being chosen.
  final String? title;

  /// Whether menus open as bottom sheets here: touch on a phone.
  static bool asSheet(BuildContext context) =>
      context.input.isTouch && context.screen.compact;

  @override
  State<AdaptiveMenu> createState() => _AdaptiveMenuState();
}

class _AdaptiveMenuState extends State<AdaptiveMenu>
    implements AdaptiveMenuController {
  final _anchor = MenuController();

  /// The latest entries, so an open sheet shows toggles as they change.
  late final _entries = ValueNotifier(widget.entries);
  bool _sheetOpen = false;

  @override
  void didUpdateWidget(AdaptiveMenu old) {
    super.didUpdateWidget(old);
    // Not during build: the sheet listening is another route.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entries.value = widget.entries;
    });
  }

  @override
  void dispose() {
    _entries.dispose();
    super.dispose();
  }

  @override
  bool get isOpen => _sheetOpen || _anchor.isOpen;

  @override
  void open() {
    if (isOpen) return;
    if (!AdaptiveMenu.asSheet(context)) return _anchor.open();
    setState(() => _sheetOpen = true);
    showAdaptiveSheet<void>(
      context,
      builder: (context) => _SheetMenu(title: widget.title, entries: _entries),
    ).whenComplete(() {
      if (mounted) setState(() => _sheetOpen = false);
    });
  }

  @override
  void close() {
    if (_sheetOpen) {
      Navigator.of(context, rootNavigator: true).maybePop();
    } else {
      _anchor.close();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => MenuAnchor(
      controller: _anchor,
      alignmentOffset: const Offset(-menuBleed, Space.s4 - menuBleed),
      style: menuAnchorStyle,
      menuChildren: [
        Padding(
          padding: const EdgeInsets.all(menuBleed),
          child: MenuPanel(
            minWidth: widget.matchAnchorWidth && box.hasBoundedWidth
                ? box.maxWidth
                : widget.minWidth,
            children: [
              for (final a in widget.entries)
                MenuOption(
                  label: a.label,
                  icon: a.icon,
                  checked: a.checked,
                  destructive: a.destructive,
                  closeOnActivate: !a.staysOpen,
                  onPressed: a.onPressed,
                ),
            ],
          ),
        ),
      ],
      builder: (context, _, _) => widget.builder(context, this),
    ),
  );
}

/// The menu as a sheet: a scrolling list of touch-height rows. Commands
/// close the sheet before they run, so a confirmation they open stays.
class _SheetMenu extends StatelessWidget {
  const _SheetMenu({required this.title, required this.entries});

  final String? title;
  final ValueNotifier<List<MenuAction>> entries;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: entries,
    builder: (context, entries, _) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s8),
            child: Text(
              title!,
              style: context.type.subtitle.copyWith(
                color: context.colors.foreground,
              ),
            ),
          ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final a in entries)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: ControlHeights.touch,
                    ),
                    child: MenuOption(
                      label: a.label,
                      icon: a.icon,
                      checked: a.checked,
                      destructive: a.destructive,
                      closeOnActivate: false,
                      onPressed: () {
                        if (a.staysOpen) return a.onPressed();
                        Navigator.of(context).pop();
                        a.onPressed();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (entries.any((a) => a.staysOpen)) ...[
          const SizedBox(height: Space.s16),
          SButton.primary(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ],
    ),
  );
}
