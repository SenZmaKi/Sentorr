import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../imdb/models.dart';
import '../../../titles/pick_up.dart';
import '../../shared/play_route.dart';
import '../../shared/title_format.dart';
import '../../shared/title_icons.dart';
import '../list_badge.dart';
import '../title_artwork.dart';
import 'card_parts.dart';
import 'poster_card.dart';
import 'title_preview.dart';

/// Kind, year and first genre: what a browsing viewer compares first.
List<MetaItem> titleFacts(ImdbTitle t) => [
  MetaItem(kindLabel(t), icon: kindIcon(t)),
  if (yearLabel(t) case final year?) MetaItem(year),
  if (t.genres.isNotEmpty) MetaItem(t.genres.first),
];

/// Spoken summary of a title card; [lead] prefixes context such as a rank.
String describeTitle(ImdbTitle t, [String? lead]) => [
  ?lead,
  t.title,
  kindLabel(t),
  ?yearLabel(t),
  if (t.rating != null) 'rated ${t.rating!.toStringAsFixed(1)}',
  if (t.voteCount != null) '${compactCount(t.voteCount!)} votes',
].join(', ');

/// The standard [PosterCard] for an IMDb title: [onOpen] on tap, and a
/// [TitlePreview] while hovered, its Play naming where the viewer left off.
PosterCard titlePoster(
  ImdbTitle t, {
  String? lead,
  required VoidCallback onOpen,
  VoidCallback? onPlay,
  List<MetaItem>? meta,
}) => PosterCard(
  title: t.title,
  meta: meta ?? titleFacts(t),
  rating: t.rating?.toStringAsFixed(1),
  artwork: TitleArtwork(image: t.poster),
  stamp: ListBadge(titleId: t.id, compact: true),
  semanticLabel: describeTitle(t, lead),
  onTap: onOpen,
  preview: (_) => PickUpPreview(title: t, onOpen: onOpen, onPlay: onPlay),
);

/// A [TitlePreview] whose Play reads "Resume" or "Continue S1 E4" for a
/// title the viewer has started.
class PickUpPreview extends ConsumerWidget {
  const PickUpPreview({
    super.key,
    required this.title,
    required this.onOpen,
    this.onPlay,
  });

  final ImdbTitle title;
  final VoidCallback onOpen;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TitlePreview(
    title: title,
    onOpen: onOpen,
    onPlay: onPlay,
    playLabel: pickUpLabel(ref.watch(pickUpPresentationProvider(title.id))),
  );
}
