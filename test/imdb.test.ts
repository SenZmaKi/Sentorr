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
  callback: () => Promise<Pagination<any>>,
) {
  const page = await callback();
  emptyArrayTest(name, page.results);
  expect(page.next).toBeTruthy();
    // For typescript to not complain about page.next being undefined
  if (page.next) {
    const page2 = await page.next();
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
  const callback = async () => search({ searchTerm: MOVIE_TITLE });
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
  const callback = async () =>
    getReviews({ mediaID: SHOW_IMDB_ID, hideSpoilers: true });
  await paginationTest("getReviews", callback);
});

test("getTop10Trending", async () => {
  await emptyArrayTestHandler("getTop10Trending", getTop10Trending);
});

test("getEpisodes", async () => {
  const callback = async () => getEpisodes(SHOW_IMDB_ID, 1);
  await paginationTest("getEpisodes", callback);
});

test("getTop10OfAllTime", async () => {
  await emptyArrayTestHandler("getTop10OfAllTime", getTop10OfAllTime);
});
