import 'package:flutter/material.dart';

import '../../../imdb/models.dart';
import '../../shared/title_format.dart';
import '../../shared/title_icons.dart';
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
/// [TitlePreview] while hovered.
PosterCard titlePoster(
  ImdbTitle t, {
  String? lead,
  required VoidCallback onOpen,
  VoidCallback? onPlay,
}) => PosterCard(
  title: t.title,
  meta: titleFacts(t),
  rating: t.rating?.toStringAsFixed(1),
  artwork: TitleArtwork(image: t.poster),
  semanticLabel: describeTitle(t, lead),
  onTap: onOpen,
  preview: (_) => TitlePreview(title: t, onOpen: onOpen, onPlay: onPlay),
);
