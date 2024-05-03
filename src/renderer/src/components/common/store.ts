import { writable } from "svelte/store";
import type { Media } from "$backend/imdb/types";
import { Page } from "./types";

export const currentPage = writable(Page.Search);
export const previewMedia = writable<Promise<Media> | undefined>(undefined);
export const loadingTask = writable<(() => Promise<void>) | undefined>(
  undefined,
);
