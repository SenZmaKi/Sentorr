import 'package:flutter/material.dart';

import '../../torrents/models.dart';
import '../shared/theme/theme.dart';

/// A torrent site's own logo, so sources are recognizable at a glance.
class SourceIcon extends StatelessWidget {
  const SourceIcon(this.source, {super.key, this.size = IconSizes.control});

  final TorrentSourceId source;
  final double size;

  String get _asset => switch (source) {
    TorrentSourceId.pirateBay => 'assets/images/sources/pirate_bay.png',
    TorrentSourceId.yts => 'assets/images/sources/yts.png',
    TorrentSourceId.bitsearch => 'assets/images/sources/bitsearch.png',
  };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 5),
      child: Image.asset(
        _asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        errorBuilder: (context, _, _) => Icon(
          Icons.travel_explore,
          size: size,
          color: context.colors.foregroundMuted,
        ),
      ),
    );
  }
}
