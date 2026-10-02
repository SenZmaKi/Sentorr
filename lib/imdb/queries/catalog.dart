import 'summary.dart';

const trendingTitlesQuery =
    r'''
query SentorrTrending($first: Int!) {
 topMeterTitles(first: $first) { edges { node { ...SentorrTitleSummary } } }
}
''' +
    titleSummaryFragment;
const searchTitlesQuery =
    r'''
query SentorrSearch($first: Int!, $after: String,
 $constraints: AdvancedTitleSearchConstraints, $sort: AdvancedTitleSearchSort) {
 advancedTitleSearch(first: $first, after: $after, constraints: $constraints, sort: $sort) {
  total pageInfo { hasNextPage endCursor }
  edges { node { title { ...SentorrTitleSummary } } }
 }
}
''' +
    titleSummaryFragment;
