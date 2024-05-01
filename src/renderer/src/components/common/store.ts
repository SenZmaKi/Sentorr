import { derived, writable } from "svelte/store";
import type { Media } from "$backend/imdb/types";
import { Page } from "./types";

export let currentPage = writable(Page.Search);
export let previewMedia = writable<Media | undefined>(undefined);
export let loadingTask = writable<(() => Promise<void>) | undefined>(undefined);