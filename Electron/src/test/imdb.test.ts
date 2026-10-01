import {
  search,
  getFanFavorites,
  getPopularTitles,
  getSessionCookies,
  getMedia,
  getEpisode,
  getReviews,
  getTop10Trending,
  getTop10OfAllTime,
  getEpisodes,
} from "@/backend/imdb/api";
import { type Pagination } from "@/backend/imdb/types";
import { SHOW_IMDB_ID, MOVIE_TITLE, EPISODE_IMDB_ID } from "./common/constants";
import {
  failIfEmpty,
  failIfEmptyHandler,
  saveResults,
} from "./common/functions";
import { test, expect } from "bun:test";

async function paginationTest(
  name: string,
  callback: (nextPageKey: string | undefined) => Promise<Pagination<any>>,
) {
  const page = await callback(undefined);
  failIfEmpty(name, page.results);
  if (page.nextPageKey) {
    const page2 = await callback(page.nextPageKey);
    failIfEmpty(`${name}2`, page2.results);
  }
}

test("getSessionCookies", async () => {
  await failIfEmptyHandler("imdb/setSessionCookies", getSessionCookies);
});

test("search", async () => {
  const callback = async (nextPageKey: string | undefined) =>
    search({ searchTerm: MOVIE_TITLE }, nextPageKey);
  await paginationTest("imdb/search", callback);
});

test("fanFavorites", async () => {
  await failIfEmptyHandler("imdb/fanFavorites", getFanFavorites);
});

test("popularTitles", async () => {
  await failIfEmptyHandler("imdb/popularTitles", getPopularTitles);
});

test("getMedia", async () => {
  const media = await getMedia(SHOW_IMDB_ID);
  saveResults("imdb/getMedia", media);
  expect(media.id).toBeTruthy();
});

test("getEpisode", async () => {
  const episode = await getEpisode(EPISODE_IMDB_ID);
  saveResults("imdb/getEpisode", episode);
  expect(episode.id).toBeTruthy();
});

test("getReviews", async () => {
  const callback = async (nextPageKey: string | undefined) =>
    getReviews(SHOW_IMDB_ID, true, nextPageKey);
  await paginationTest("imdb/getReviews", callback);
});

test("getTop10Trending", async () => {
  await failIfEmptyHandler("imdb/getTop10Trending", getTop10Trending);
});

test("getEpisodes", async () => {
  const callback = async (nextPageKey: string | undefined) =>
    getEpisodes(SHOW_IMDB_ID, 1, nextPageKey);
  await paginationTest("imdb/getEpisodes", callback);
});

test("getTop10OfAllTime", async () => {
  await failIfEmptyHandler("imdb/getTop10OfAllTime", getTop10OfAllTime);
});
