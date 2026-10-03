import 'package:flutter/material.dart';

import '../../shared/window_manager.dart';
import 'sections/appearance_section.dart';
import 'sections/choosing_section.dart';
import 'sections/downloads_section.dart';
import 'sections/following_section.dart';
import 'sections/network_section.dart';
import 'sections/notifications_section.dart';
import 'sections/sources_section.dart';
import 'sections/storage_section.dart';
import 'sections/streaming_section.dart';
import 'sections/updates_section.dart';
import 'sections/watching_section.dart';
import 'sections/window_section.dart';

/// Where a category sits in the navigation: what Sentorr fetches, what it
/// keeps track of for you, and the app itself.
enum SettingsArea {
  torrents('Torrents'),
  library('Library'),
  app('App');

  const SettingsArea(this.label);

  final String label;
}

/// Settings pages, in navigation order. Each setting lives in exactly one,
/// the one a person would look in first.
enum SettingsCategory {
  torrents(
    SettingsArea.torrents,
    'Finding torrents',
    Icons.travel_explore_rounded,
    'Sources, quality and languages, for playing and downloading',
  ),
  streaming(
    SettingsArea.torrents,
    'Streaming',
    Icons.play_circle_outline_rounded,
    'Buffering, and the torrents kept after watching',
  ),
  downloads(
    SettingsArea.torrents,
    'Downloads',
    Icons.download_rounded,
    'Folder, queue, new episodes and sharing',
  ),
  network(
    SettingsArea.torrents,
    'Network',
    Icons.lan_outlined,
    'Speed limits, finding peers, proxy and VPN',
  ),
  watching(
    SettingsArea.library,
    'Watching',
    Icons.history_rounded,
    'Continue watching and the series you follow',
  ),
  notifications(
    SettingsArea.library,
    'Notifications',
    Icons.notifications_outlined,
    'New episodes and finished downloads',
  ),
  general(
    SettingsArea.app,
    'General',
    Icons.tune_rounded,
    'Theme, startup and the window',
  ),
  storage(
    SettingsArea.app,
    'Storage',
    Icons.storage_rounded,
    'Cache space and resetting settings',
  ),
  updates(
    SettingsArea.app,
    'Updates',
    Icons.system_update_alt_rounded,
    'Version and new releases',
  );

  const SettingsCategory(this.area, this.title, this.icon, this._subtitle);

  final SettingsArea area;
  final String title;
  final IconData icon;
  final String _subtitle;

  /// What the page holds on this device.
  String get subtitle =>
      this == general && !supportsWindowCustomization ? 'Theme' : _subtitle;

  /// Categories in navigation order.
  static List<SettingsCategory> get available => values;

  Widget get content => switch (this) {
    torrents => const _Groups([SourcesSection(), ChoosingSection()]),
    streaming => const StreamingSection(),
    downloads => const DownloadsSection(),
    network => const NetworkSection(),
    watching => const _Groups([WatchingSection(), FollowingSection()]),
    notifications => const NotificationsSection(),
    general => _Groups([
      const AppearanceSection(),
      if (supportsWindowCustomization) const WindowSection(),
    ]),
    storage => const StorageSection(),
    updates => const UpdatesSection(),
  };
}

/// Settings groups from several sections, one under another.
class _Groups extends StatelessWidget {
  const _Groups(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
}
