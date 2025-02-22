import { writable } from "svelte/store";
import { type BaseResult, type Media } from "@/backend/imdb/types";
import { MediaCardType, Page } from "./types";

export const currentPage = writable(Page.Player);
export const previewResult = writable<BaseResult | undefined>(undefined);
export const previewMedia = writable<Promise<Media> | undefined>(undefined);
export const mediaCardType = writable(MediaCardType.Complex);
