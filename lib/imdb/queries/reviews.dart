const reviewsQuery = r'''
query SentorrReviews($id: ID!, $first: Int!, $after: ID, $filter: ReviewsFilter) {
 title(id: $id) {
  reviews(first: $first, after: $after, filter: $filter,
   sort: { by: HELPFULNESS_SCORE, order: DESC }) {
   total pageInfo { hasNextPage endCursor }
   edges { node {
    id author { nickName } authorRating summary { originalText }
    text { originalText { plainText } } submissionDate
    helpfulness { upVotes downVotes } spoiler
   } }
  }
 }
}
''';
