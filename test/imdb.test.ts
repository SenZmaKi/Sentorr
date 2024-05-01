import {
  search,
  getFanFavorites,
  getPopularTitles,
  setSessionCookies,
  getMedia,
  getReviews,
  getTop10Trending,
  getTop10OfAllTime,
  getEpisodes,
} from "../src/backend/imdb/api.js";
import { Pagination } from "../src/backend/imdb/types.js";
import { SHOW_IMDB_ID, MOVIE_TITLE } from "./utils/constants.js";
import {
  emptyArrayTest,
  emptyArrayTestHandler,
  saveResults,
} from "./utils/functions.js";
import { test, expect } from "bun:test";

async function paginationTest(
  name: string,
  callback: () => Promise<Pagination<any>>,
) {
  const page = await callback();
  emptyArrayTest(name, page.results);
  expect(page.next).toBeTruthy();
  if (page.next) { // for typescript to not complain about page.next being undefined
    const page2 = await page.next();
    emptyArrayTest(`${name}2`, page2.results);
  }
}

test("fakeTest", () => {
  console.log("Fake test ran");
});

test("setSessionCookies", async () => {
  await emptyArrayTestHandler("setSessionCookies", setSessionCookies);
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
  const callback = async () => getReviews(SHOW_IMDB_ID, true);
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