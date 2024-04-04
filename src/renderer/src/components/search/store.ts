import { writable, derived, type Writable } from "svelte/store";
import { search } from "$backend/imdb/api.js";
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
import { DEBUG } from "@/utils/constants";

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


export const formattedMediaTypes = {
  Movie: MediaType.Movie,
  "TV Series": MediaType.TVSeries,
  Short: MediaType.Short,
  "TV Mini Series": MediaType.TVMiniSeries,
  "TV Movie": MediaType.TVMovie,
  "TV Special": MediaType.TVSpecial,
  "TV Short": MediaType.TVShort,
  Documentary: MediaType.Documentary,
} as const;

export const formattedMediaTypesVariants = Object.keys(formattedMediaTypes);
export let selectedFormattedMediaTypes: Writable<MediaType[] | undefined> = writable(undefined);
