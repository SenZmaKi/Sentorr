import { writable, derived, type Writable } from "svelte/store";
import {
  MediaType,
  SortBy,
  type Range,
  type ReleaseDateRange,
  SortOrder,
  Genre,
} from "$backend/imdb/types.js";
import {
  DEFAULT_SORT_BY,
  DEFAULT_SORT_ORDER,
} from "$backend/imdb/constants.js";

// Individual writable stores for each field in searchFilters
export let searchTerm: Writable<string | undefined> = writable(undefined);
export let releaseDateRange: Writable<ReleaseDateRange | undefined> =
  writable(undefined);
export let ratingRange: Writable<Range | undefined> = writable(undefined);
export let runtimeRangeMinutes: Writable<Range | undefined> =
  writable(undefined);
export let genres: Writable<Genre[] | undefined> = writable(undefined);
export let mediaTypes: Writable<MediaType[] | undefined> = writable(undefined);
export let sortBy: Writable<SortBy | undefined> = writable(DEFAULT_SORT_BY);
export let sortOrder: Writable<SortOrder | undefined> =
  writable(DEFAULT_SORT_ORDER);

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
    $searchTerm,
    $releaseDateRange,
    $ratingRange,
    $runtimeRangeMinutes,
    $genres,
    $mediaTypes,
    $sortBy,
    $sortOrder,
  ]) => ({
    searchTerm: $searchTerm,
    releaseDateRange: $releaseDateRange,
    ratingRange: $ratingRange,
    runtimeRangeMinutes: $runtimeRangeMinutes,
    genres: $genres,
    mediaTypes: $mediaTypes,
    sortBy: $sortBy,
    sortOrder: $sortOrder,
  }),
);


export let selectedFormattedMediaTypes: Writable<MediaType[] | undefined> = writable(undefined);
