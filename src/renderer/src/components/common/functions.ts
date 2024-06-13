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
  fetcher: (nextPageKey: string | undefined) => Promise<Pagination<T[]>>,
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
  const addNewResults = (newResults: T[]) => {
    accumulatedResults.update((oldResults) => {
      oldResults.splice(-placeholderResultsCount);
      return [...oldResults, ...newResults];
    });
  };
  let nextPageKey: string | undefined = undefined;
  fetcher(undefined).then(({ results, nextPageKey: nPK }) => {
    addNewResults(results);
    nextPageKey = nPK;
  });
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
      if (nextPageKey) {
        addPlaceholders();
        const pagination = await fetcher(nextPageKey);
        const newResults = pagination.results;
        nextPageKey = pagination.nextPageKey;
        addNewResults(newResults);
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

/**
 * Creates a function that triggers a callback when an HTML element enters the viewport.
 *
 * @param callback - The function to be called when the element is in the viewport.
 * @returns - A function that takes an HTML element as an argument and observes it.
 * When the element enters the viewport, the callback function is triggered.
 */
export function makeActionWhenInViewport(callback: () => void) {
  return (element: HTMLElement) => {
    const observer = new IntersectionObserver((entries) => {
      if (entries[0].isIntersecting) {
        callback();
      }
    });

    observer.observe(element);
  };
}
