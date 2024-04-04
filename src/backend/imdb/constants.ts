import { Genre, MediaType, SortBy, SortOrder } from "./types";

export const DEFAULT_SORT_BY = SortBy.POPULARITY;
export const DEFAULT_SORT_ORDER = SortOrder.ASC 
export const SortBys = Object.values(SortBy) as SortBy[];
export const MediaTypes = Object.values(MediaType) as MediaType[];
export const Genres = Object.values(Genre) as Genre[];
export const MAX_RATING = 10;
