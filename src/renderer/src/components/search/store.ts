import { writable, derived } from "svelte/store";
import {
  SortBy,
  type Range,
  type ReleaseDateRange,
  SortOrder,
  Genre,
  MediaType,
} from "$backend/imdb/types.js";
import {
  DEFAULT_SORT_BY,
  DEFAULT_SORT_ORDER,
} from "$backend/imdb/constants.js";

// Individual stores for each field in searchFilters
export const searchTerm = writable<string | undefined>(undefined);
export const releaseDateRange = writable<ReleaseDateRange | undefined>(
  undefined,
);
export const ratingRange = writable<Range | undefined>(undefined);
export const runtimeRangeMinutes = writable<Range | undefined>(undefined);
export const genres = writable<Genre[] | undefined>(undefined);
export const mediaTypes = writable<MediaType[] | undefined>(undefined);
export const sortBy = writable<SortBy | undefined>(DEFAULT_SORT_BY);
export const sortOrder = writable<SortOrder | undefined>(DEFAULT_SORT_ORDER);

export const searchFilters = derived(
  [
    searchTerm,
    releaseDateRange,
    ratingRange,
    runtimeRangeMinutes,
    genres,
    mediaTypes,
    sortBy,
    sortOrder,
  ],
  ([
    searchTerm,
    releaseDateRange,
    ratingRange,
    runtimeRangeMinutes,
    genres,
    mediaTypes,
    sortBy,
    sortOrder,
  ]) => ({
    searchTerm,
    releaseDateRange,
    ratingRange,
    runtimeRangeMinutes,
    genres,
    mediaTypes,
    sortBy,
    sortOrder,
  }),
);
