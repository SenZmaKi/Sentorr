import 'package:flutter/material.dart';

/// One player command: how the legend writes it ([caps]) and which keys it
/// lights on the keyboard ([keys], ids from `shortcut_keyboard.dart`).
typedef PlayerShortcut = ({String action, List<String> caps, Set<String> keys});

/// What [PlayerShortcuts] handles, grouped for reading; keep the two in step.
const shortcutGroups = <(String, List<PlayerShortcut>)>[
  (
    'Playback',
    [
      (action: 'Play or pause', caps: ['Space', 'K'], keys: {'space', 'k'}),
      (action: 'Back or forward 10 s', caps: ['J', 'L'], keys: {'j', 'l'}),
      (
        action: 'Back or forward 5 s',
        caps: ['←', '→'],
        keys: {'left', 'right'},
      ),
      (
        action: 'Jump to 0–90%',
        caps: ['0–9'],
        keys: {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'},
      ),
      (action: 'Slower or faster', caps: ['<', '>'], keys: {'shift', ',', '.'}),
      (action: 'Frame by frame (paused)', caps: [',', '.'], keys: {',', '.'}),
      (
        action: 'Next or previous',
        caps: ['Shift N', 'Shift P'],
        keys: {'shift', 'n', 'p'},
      ),
    ],
  ),
  (
    'Sound and captions',
    [
      (action: 'Volume up or down', caps: ['↑', '↓'], keys: {'up', 'down'}),
      (action: 'Mute', caps: ['M'], keys: {'m'}),
      (action: 'Captions on or off', caps: ['C'], keys: {'c'}),
    ],
  ),
  (
    'View',
    [
      (action: 'Full screen', caps: ['F'], keys: {'f'}),
      (action: 'Mini player', caps: ['I'], keys: {'i'}),
      (action: 'Episodes', caps: ['Q'], keys: {'q'}),
      (action: 'Torrents', caps: ['T'], keys: {'t'}),
      (action: 'Keyboard shortcuts', caps: ['?'], keys: {'shift', '/'}),
      (
        action: 'Close panel or leave full screen',
        caps: ['Esc'],
        keys: {'esc'},
      ),
    ],
  ),
];

final _all = [for (final (_, shortcuts) in shortcutGroups) ...shortcuts];

/// Every key some shortcut uses.
final boundKeys = {for (final s in _all) ...s.keys};

final _byKey = <String, Set<PlayerShortcut>>{
  for (final key in boundKeys)
    key: {
      for (final s in _all)
        if (s.keys.contains(key)) s,
    },
};

/// The shortcuts that use [key]; the same set each time, so lighting a key
/// already lit notifies nobody.
Set<PlayerShortcut> shortcutsOn(String key) => _byKey[key] ?? const {};

/// Glyphs printed on bound caps, as media keys carry theirs.
const keyGlyphs = <String, IconData>{
  'space': Icons.play_arrow_rounded,
  'k': Icons.play_arrow_rounded,
  'j': Icons.replay_10_rounded,
  'l': Icons.forward_10_rounded,
  'm': Icons.volume_off_rounded,
  'c': Icons.closed_caption_outlined,
  'f': Icons.fullscreen_rounded,
  'i': Icons.picture_in_picture_alt_rounded,
  'q': Icons.video_library_outlined,
  't': Icons.swap_horiz_rounded,
  'n': Icons.skip_next_rounded,
  'p': Icons.skip_previous_rounded,
};

/// Legends drawn as icons, since not every face carries these glyphs.
const capIcons = <String, IconData>{
  '←': Icons.arrow_left_rounded,
  '→': Icons.arrow_right_rounded,
  '↑': Icons.arrow_drop_up_rounded,
  '↓': Icons.arrow_drop_down_rounded,
  '⌫': Icons.backspace_outlined,
};

/// The shortcuts lit by whatever key or legend row is hovered or tapped.
typedef LitShortcuts = ValueNotifier<Set<PlayerShortcut>>;
