import 'package:flutter/material.dart';

import '../../shared/window_manager.dart';
import 'sections/appearance_section.dart';
import 'sections/downloads_section.dart';
import 'sections/following_section.dart';
import 'sections/network_section.dart';
import 'sections/notifications_section.dart';
import 'sections/playback_section.dart';
import 'sections/sources_section.dart';
import 'sections/storage_section.dart';
import 'sections/streaming_section.dart';
import 'sections/watching_section.dart';
import 'sections/window_section.dart';

/// Settings pages, in navigation order. [keywords] lists what each holds,
/// so search can tell when nothing matches.
enum SettingsCategory {
  playback(
    'Playback',
    Icons.play_circle_outline_rounded,
    'Quality, languages and autoplay',
    'preferred quality resolution audio languages minimum seeders show the '
        'torrent before playing countdown starting playback choosing',
  ),
  sources(
    'Sources',
    Icons.travel_explore_rounded,
    'Torrent sites to search',
    'torrent sources pirate bay yts bitsearch providers sites',
  ),
  downloads(
    'Downloads',
    Icons.download_rounded,
    'Folder, queue and sharing',
    'download folder location simultaneous queue pause while watching '
        'seeding sharing ratio upload',
  ),
  network(
    'Network',
    Icons.lan_outlined,
    'Speed limits and finding peers',
    'network download limit upload limit speed bandwidth connections utp dht '
        'local peer discovery upnp nat port router',
  ),
  streaming(
    'Streaming engine',
    Icons.hub_outlined,
    'Buffering and torrent files',
    'buffering read ahead memory cache connection timeout stall torrent '
        'files torrent folder keep recent torrents',
  ),
  watching(
    'Continue watching',
    Icons.history_rounded,
    'Progress, followed series and auto-download',
    'in progress continue watching history resume clear following series '
        'unfollow new episodes auto download automatic keep episodes',
  ),
  notifications(
    'Notifications',
    Icons.notifications_outlined,
    'New episodes and finished downloads',
    'notifications alerts new episodes airing mute downloads ready',
  ),
  appearance(
    'Appearance',
    Icons.palette_outlined,
    'Theme',
    'theme mode dark light system',
  ),
  window(
    'Window',
    Icons.web_asset_rounded,
    'Startup, tray and window',
    'window launch at startup close to tray always on top open maximized '
        'open in full screen desktop',
  ),
  storage(
    'Cache and storage',
    Icons.storage_rounded,
    'Disk usage, cleanup and reset',
    'image cache limit clear data network cache kept torrents reset settings',
  );

  const SettingsCategory(this.title, this.icon, this.subtitle, this.keywords);

  final String title;
  final IconData icon;
  final String subtitle;
  final String keywords;

  /// Categories this device offers.
  static List<SettingsCategory> get available => [
    for (final c in values)
      if (c != window || supportsWindowCustomization) c,
  ];

  Widget get content => switch (this) {
    playback => const PlaybackSection(),
    sources => const SourcesSection(),
    downloads => const DownloadsSection(),
    network => const NetworkSection(),
    streaming => const StreamingSection(),
    watching => const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [WatchingSection(), FollowingSection()],
    ),
    notifications => const NotificationsSection(),
    appearance => const AppearanceSection(),
    window => const WindowSection(),
    storage => const StorageSection(),
  };
}
