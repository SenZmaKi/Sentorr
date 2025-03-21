import { writable, get } from "svelte/store";
import { type BaseResult, type Media } from "@/backend/imdb/types";
import { MediaCardType, Page } from "./types";

export const previewResult = writable<BaseResult | undefined>(undefined);
export const previewMedia = writable<Promise<Media> | undefined>(undefined);
export const mediaCardType = writable(MediaCardType.Complex);
export const config = writable(await window.ipc.config.getConfig());
config.subscribe(async (newConfig) => {
  // console.log("config changed:", newConfig);
  await window.ipc.config.setConfig(newConfig);
});
export function getCurrentMediaProgress() {
  const { allMediaProgress } = get(config);
  const mediaProgress =
    allMediaProgress.current &&
    allMediaProgress.mediaProgress[allMediaProgress.current];
  return mediaProgress;
}
export const currentPage = writable(
  get(config).allMediaProgress.current ? Page.Player : Page.Search,
);
