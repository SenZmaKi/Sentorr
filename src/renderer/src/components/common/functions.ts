import type { Pagination } from "$backend/imdb/types";
import { writable } from "svelte/store";
import {
  currentPage,
  loadingTask,
  previewMedia,
} from "$frontend/src/components/common/store";
import type { Media } from "$backend/imdb/types";
import { Page } from "./types";

export function prettyFormatNumber(num: number): string {
  if (num >= 1000_000_000) {
    return (num / 1000_000_000).toFixed(1).replace(/\.0$/, "") + "B";
  }
  if (num >= 1000_000) {
    return (num / 1000_000).toFixed(1).replace(/\.0$/, "") + "M";
  }
  if (num >= 1000) {
    return (num / 1000).toFixed(1).replace(/\.0$/, "") + "K";
  }
  return num.toString();
}

export function secondsToHm(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) {
    return `${minutes}m`;
  }
  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  if (remainingMinutes === 0) return `${hours}h`;
  if (hours === 0) return `${remainingMinutes}m`;
  return `${hours}h ${remainingMinutes}m`;
}

export function createInfiniteScrollStore<T>(
  pagination: Promise<Pagination<T[]>>,
  horizontal: boolean,
  placeholderResultsCount = 25,
) {
  const accumulatedResults = writable<(T | undefined)[]>([]);
  const addPlaceholders = () => {
    accumulatedResults.update((data) => [
      ...data,
      ...Array.from({ length: placeholderResultsCount }, () => undefined),
    ]);
  };
  addPlaceholders();
  const removePlaceholders = () => {
    accumulatedResults.update((data) =>
      data.slice(undefined, -placeholderResultsCount),
    );
  };
  (async () => {
    const results = (await pagination).results;
    removePlaceholders();
    accumulatedResults.update((data) => [...data, ...results]);
  })();
  let fetchingMoreResults = false;
  async function infiniteScroll(event: Event | null) {
    if (!event || fetchingMoreResults) return;
    const element = event.target as HTMLElement;
    const nearingEnd = horizontal
      ? (element.clientWidth + element.scrollLeft) / element.scrollWidth >= 0.7
      : (element.clientHeight + element.scrollTop) / element.scrollHeight >=
        0.7;
    if (nearingEnd) {
      fetchingMoreResults = true;
      const awaitedPagination = await pagination;
      if (awaitedPagination.next) {
        pagination = awaitedPagination.next();
        addPlaceholders();
        const results = (await pagination).results;
        removePlaceholders();
        accumulatedResults.update((data) => [...data, ...results]);
      }
      fetchingMoreResults = false;
    }
  }

  return [accumulatedResults, infiniteScroll] as const;
}

function clearPreviewMedia() {
  previewMedia.set(undefined);
}
export function switchToPreviewPage(media: Promise<Media>): void {
  previewMedia.set(media);
  currentPage.set(Page.Preview);
}

export function switchToSearchPage(): void {
  currentPage.set(Page.Search);
  clearPreviewMedia();
}
export function setLoadingTask(task: () => Promise<void>) {
  loadingTask.update((currTask) => (currTask ? currTask : task));
}
export function clearLoadingTask(): void {
  loadingTask.set(undefined);
}
