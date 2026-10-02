import 'summary.dart';

const creditFragment = '''
fragment SentorrCredit on Credit {
 __typename name { id nameText { text } primaryImage { url width height } }
 category { id text }
 ... on Cast { characters { name } }
}
''';
const titleDetailsQuery =
    r'''
query SentorrDetails($id: ID!, $first: Int!) {
 title(id: $id) {
  ...SentorrTitleSummary
  releaseDate { year month day } certificate { rating }
  credits(first: $first) {
   edges { node { ...SentorrCredit } } pageInfo { hasNextPage endCursor }
  }
  principalCredits {
   category { id text }
   credits { __typename name { id nameText { text } primaryImage { url width height } }
    ... on Cast { characters { name } }
   }
  }
  moreLikeThisTitles(first: $first) {
   edges { node { ...SentorrTitleSummary } } pageInfo { hasNextPage endCursor }
  }
  images(first: $first) {
   edges { node { id url width height type } } pageInfo { hasNextPage endCursor }
  }
  episodes { seasons { number } episodes(first: 1) { total } }
  primaryVideos(first: 2) {
   edges { node { id name { value } description { value } thumbnail { url width height } } }
  }
 }
}
''' +
    titleSummaryFragment +
    creditFragment;
const creditsQuery =
    r'''
query SentorrCredits($id: ID!, $first: Int!, $after: ID) {
 title(id: $id) { credits(first: $first, after: $after) {
  edges { node { ...SentorrCredit } } pageInfo { hasNextPage endCursor }
 } }
}
''' +
    creditFragment;
const recommendationsQuery =
    r'''
query SentorrRecommendations($id: ID!, $first: Int!, $after: ID) {
 title(id: $id) { moreLikeThisTitles(first: $first, after: $after) {
  edges { node { ...SentorrTitleSummary } } pageInfo { hasNextPage endCursor }
 } }
}
''' +
    titleSummaryFragment;
const imagesQuery = r'''
query SentorrImages($id: ID!, $first: Int!, $after: ID) {
 title(id: $id) { images(first: $first, after: $after) {
  edges { node { id url width height type } } pageInfo { hasNextPage endCursor }
 } }
}
''';
