import 'package:flutter/material.dart';

import '../../components/adaptive_sheet.dart';
import '../../components/buttons.dart';
import '../../components/dialog_actions.dart';
import '../../shared/theme/theme.dart';
import 'shortcut_keyboard.dart';
import 'shortcut_map.dart';

/// Shows the player's keyboard shortcuts on a keyboard, with a legend.
Future<void> showPlayerShortcuts(BuildContext context) => showAdaptiveSheet(
  context,
  maxWidth: 840,
  builder: (context) => const _ShortcutsBody(),
);

class _ShortcutsBody extends StatefulWidget {
  const _ShortcutsBody();

  @override
  State<_ShortcutsBody> createState() => _ShortcutsBodyState();
}

class _ShortcutsBodyState extends State<_ShortcutsBody> {
  final _lit = LitShortcuts(const {});

  @override
  void dispose() {
    _lit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Keyboard shortcuts',
        style: context.type.title.copyWith(color: context.colors.foreground),
      ),
      const SizedBox(height: Space.s16),
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShortcutKeyboard(lit: _lit),
              const SizedBox(height: Space.s24),
              _Legend(lit: _lit),
            ],
          ),
        ),
      ),
      const SizedBox(height: Space.s16),
      DialogActions(
        children: [
          SButton.primary(
            label: 'Done',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ],
  );
}

/// The groups side by side when there is room, else stacked.
class _Legend extends StatelessWidget {
  const _Legend({required this.lit});

  final LitShortcuts lit;

  @override
  Widget build(BuildContext context) => MouseRegion(
    // Rows only light on enter, so moving between them never blinks.
    onExit: (_) => lit.value = const {},
    child: LayoutBuilder(
      builder: (context, box) {
        final groups = [
          for (final (title, shortcuts) in shortcutGroups)
            _Group(title: title, shortcuts: shortcuts, lit: lit),
        ];
        if (box.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: groups,
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, g) in groups.indexed) ...[
              if (i > 0) const SizedBox(width: Space.s24),
              Expanded(child: g),
            ],
          ],
        );
      },
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.shortcuts,
    required this.lit,
  });

  final String title;
  final List<PlayerShortcut> shortcuts;
  final LitShortcuts lit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: context.type.caption.copyWith(
            color: context.colors.foregroundMuted,
          ),
        ),
        const SizedBox(height: Space.s4),
        for (final s in shortcuts) _Row(shortcut: s, lit: lit),
      ],
    ),
  );
}

/// A command and its keys; hovering it lights them on the keyboard.
class _Row extends StatelessWidget {
  const _Row({required this.shortcut, required this.lit});

  final PlayerShortcut shortcut;
  final LitShortcuts lit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      onEnter: (_) => lit.value = {shortcut},
      child: ValueListenableBuilder(
        valueListenable: lit,
        builder: (context, shown, _) {
          final on = shown.contains(shortcut);
          return AnimatedContainer(
            duration: Motion.hover,
            curve: Motion.change,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s8,
              vertical: Space.s4,
            ),
            decoration: BoxDecoration(
              color: on ? c.stateHover : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    shortcut.action,
                    style: context.type.bodySmall.copyWith(
                      color: on ? c.foreground : c.foregroundSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: Space.s8),
                // Caps wrap under each other rather than squeeze the action.
                Flexible(
                  flex: 2,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: Space.s4,
                    runSpacing: Space.s4,
                    children: [
                      for (final key in shortcut.caps) _KeyCap(key, on: on),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A key written inline as a recessed cap, lit like the keyboard's when
/// its command is.
class _KeyCap extends StatelessWidget {
  const _KeyCap(this.label, {required this.on});

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = on ? c.onAction : c.foreground;
    // Lit switches at once, as the keyboard's caps do.
    return Container(
      constraints: const BoxConstraints(minWidth: Space.s24 + Space.s4),
      padding: const EdgeInsets.symmetric(
        horizontal: Space.s8,
        vertical: Space.s2,
      ),
      decoration: BoxDecoration(
        color: on ? c.action : context.depth.of(SurfaceDepth.inset).fill,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: on ? c.action : c.borderSubtle),
      ),
      child: switch (capIcons[label]) {
        final icon? => Icon(icon, size: IconSizes.control, color: ink),
        null => Text(
          label,
          textAlign: TextAlign.center,
          style: context.type.label.copyWith(color: ink),
        ),
      },
    );
  }
}
