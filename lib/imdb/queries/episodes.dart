import 'summary.dart';

const episodesQuery =
    r'''
query SentorrEpisodes($id: ID!, $season: String!, $first: Int!, $after: ID) {
 title(id: $id) { episodes {
  episodes(first: $first, after: $after, filter: { includeSeasons: [$season] }) {
   total pageInfo { hasNextPage endCursor }
   edges { node { ...SentorrTitleSummary
    releaseDate { year month day }
    series { episodeNumber { seasonNumber episodeNumber } }
   } }
  }
 } }
}
''' +
    titleSummaryFragment;
const episodeQuery =
    r'''
query SentorrEpisode($id: ID!) {
 title(id: $id) {
  ...SentorrTitleSummary releaseDate { year month day }
  series { episodeNumber { seasonNumber episodeNumber } }
 }
}
''' +
    titleSummaryFragment;
