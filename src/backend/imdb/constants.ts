import { Genre, ApiMediaType, SortBy, SortOrder, MediaType } from "./types";

export const HOME_URL = "https://imdb.com/";
export const API_ENTRY_POINT = "https://graphql.imdb.com/?operationName=";
/** Max is 50
 **/
export const DEFAULT_RESULTS_LIMIT = 50;
export const DEFAULT_LOCALE = { locale: "en-US" };
export const DEFAULT_RECOMMENDATIONS_VARIABLES = {
  ...DEFAULT_LOCALE,
  includeUserRating: false,
};
export const DEFAULT_EPISODES_RESULTS_LIMIT = 250;
export const FAN_FAVORITES_HASH =
  "7c01e0d9d8581975bf64701df0c96b02aaec777fdfc75734d68d009bde984b99";
export const POPULAR_TITLES_HASH =
  "f928c4406df23ac79204ff916c3f7429d3a44c9aac069d332a9d7eb6932c4f2f";
export const EPISODES_HASH =
  "e5b755e1254e3bc3a36b34aff729b1d107a63263dec628a8f59935c9e778c70e";
export const ADVANCED_TITLE_SEARCH_HASH =
"81b46290a78cc1e8b3d713e6a43c191c55b4dccf3e1945d6b46668945846d832";
export const REVIEWS_HASH =
  "8e851a269025170d18a33b296a5ced533529abb4e7bc3d6b96d1f36636e7f685";
// IMDB API accepts data in ISO format YYYY-MM-DD
export const MAX_RATING = 10;

export const DEFAULT_SORT_BY = SortBy.POPULARITY;
export const DEFAULT_SORT_ORDER = SortOrder.ASC;
export const SortBys = Object.values(SortBy);
export const Genres = Object.values(Genre);
export const MediaTypes = Object.values(MediaType);

export const MEDIA_TYPE_MAP = {
  [MediaType.Movie]: ApiMediaType.Movie,
  [MediaType.TVSeries]: ApiMediaType.TVSeries,
  [MediaType.Short]: ApiMediaType.Short,
  [MediaType.TVMiniSeries]: ApiMediaType.TVMiniSeries,
  [MediaType.TVMovie]: ApiMediaType.TVMovie,
  [MediaType.TVSpecial]: ApiMediaType.TVSpecial,
  [MediaType.TVShort]: ApiMediaType.TVShort,
  [MediaType.Documentary]: ApiMediaType.Documentary,
} as const;
