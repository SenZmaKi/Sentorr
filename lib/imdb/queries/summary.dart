const titleSummaryFragment = '''
fragment SentorrTitleSummary on Title {
 id titleText { text } originalTitleText { text }
 titleType { id text canHaveEpisodes }
 primaryImage { url width height }
 releaseYear { year endYear }
 ratingsSummary { aggregateRating voteCount }
 plot { plotText { plainText } }
 runtime { seconds }
 titleGenres { genres { genre { text } } }
}
''';
