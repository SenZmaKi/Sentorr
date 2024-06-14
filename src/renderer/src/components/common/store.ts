import { writable } from "svelte/store";
import type { Media } from "$backend/imdb/types";
import { MediaCardType, Page } from "./types";

export const currentPage = writable(Page.Preview);
export const previewMedia = writable<Promise<Media> | undefined>(undefined);
export const loadingTask = writable<(() => Promise<void>) | undefined>(
  undefined,
);
export const mediaCardType = writable(MediaCardType.Complex);
