import { DATE } from "@/common/constants";
import { Genre, MediaType, SortBy, SortOrder } from "./types";

export const HOME_URL = "https://imdb.com/";
export const API_ENTRY_POINT = "https://graphql.imdb.com/?operationName=";
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
  "42714660b115c035a3c14572bfd2765c622e2659f7b346e2ee7a1f24296f08e7";
// IMDB API accepts data in ISO format YYYY-MM-DD
export const DATE_STR = DATE.toISOString().split("T")[0];

export const DEFAULT_SORT_BY = SortBy.POPULARITY;
export const DEFAULT_SORT_ORDER = SortOrder.ASC;
export const SortBys = Object.values(SortBy) as SortBy[];
export const MediaTypes = Object.values(MediaType) as MediaType[];
export const Genres = Object.values(Genre) as Genre[];
export const MAX_RATING = 10;
