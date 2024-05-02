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
export let searchTerm = writable<string | undefined>(undefined);
export let releaseDateRange = writable<ReleaseDateRange | undefined>(undefined);
export let ratingRange = writable<Range | undefined>(undefined);
export let runtimeRangeMinutes = writable<Range | undefined>(undefined);
export let genres = writable<Genre[] | undefined>(undefined);
export let mediaTypes = writable<MediaType[] | undefined>(undefined);
export let sortBy = writable<SortBy | undefined>(DEFAULT_SORT_BY);
export let sortOrder = writable<SortOrder | undefined>(DEFAULT_SORT_ORDER);

export let searchFilters = derived(
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
