import {
  search,
  getFanFavorites,
  getPopularTitles,
  getSessionCookies,
  getMedia,
  getReviews,
  getTop10Trending,
  getTop10OfAllTime,
  getEpisodes,
} from "../src/backend/imdb/api";
import { Pagination } from "../src/backend/imdb/types";
import { SHOW_IMDB_ID, MOVIE_TITLE } from "./common/constants";
import {
  emptyArrayTest,
  emptyArrayTestHandler,
  saveResults,
} from "./common/functions.js";
// @ts-ignore
import { test, expect } from "bun:test";

async function paginationTest(
  name: string,
  callback: (nextPageKey: string | undefined) => Promise<Pagination<any>>,
) {
  const page = await callback(undefined);
  emptyArrayTest(name, page.results);
  if (page.nextPageKey) {
    const page2 = await callback(page.nextPageKey);
    emptyArrayTest(`${name}2`, page2.results);
  }
}

test("fakeTest", () => {
  console.log("Fake test ran");
});

test("getSessionCookies", async () => {
  await emptyArrayTestHandler("setSessionCookies", getSessionCookies);
});

test("search", async () => {
  const callback = async (nextPageKey: string | undefined) =>
    search({ searchTerm: MOVIE_TITLE }, nextPageKey);
  await paginationTest("search", callback);
});

test("fanFavorites", async () => {
  await emptyArrayTestHandler("fanFavorites", getFanFavorites);
});

test("popularTitles", async () => {
  await emptyArrayTestHandler("popularTitles", getPopularTitles);
});

test("getMedia", async () => {
  const media = await getMedia(SHOW_IMDB_ID);
  saveResults("getMedia", media);
  expect(media.title).toBeTruthy();
});

test("getReviews", async () => {
  const callback = async (nextPageKey: string | undefined) =>
    getReviews(SHOW_IMDB_ID, true, nextPageKey);
  await paginationTest("getReviews", callback);
});

test("getTop10Trending", async () => {
  await emptyArrayTestHandler("getTop10Trending", getTop10Trending);
});

test("getEpisodes", async () => {
  const callback = async (nextPageKey: string | undefined) =>
    getEpisodes(SHOW_IMDB_ID, 1, nextPageKey);
  await paginationTest("getEpisodes", callback);
});

test("getTop10OfAllTime", async () => {
  await emptyArrayTestHandler("getTop10OfAllTime", getTop10OfAllTime);
});
