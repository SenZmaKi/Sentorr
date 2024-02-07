import {
  filteredSearch,
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
import { emptyArrayTest, emptyArrayTestHandler } from "./utils/functions.js";
import { test, expect } from "bun:test";

function haveSameElements<T>(array1: T[], array2: T[]): boolean {
  if (array1.length !== array2.length) {
    return false;
  }
  return array1.find((elem, idx) => elem == array2[idx]) !== undefined;
}

async function paginationTest(callback: () => Promise<Pagination<any>>) {
  const page = await callback();
  emptyArrayTest(page.results);
  expect(page.nextPageKey).toBeTruthy();
  const page2 = await callback();
  emptyArrayTest(page2.results);
  expect(page2.nextPageKey).toBeTruthy();
  expect(
    page.nextPageKey !== page2.nextPageKey &&
    !haveSameElements(page.results, page2.results),
  );
}

test("fakeTest", () => {
  console.log("Fake test ran");
});

test("setSessionCookies", async () => {
  await emptyArrayTestHandler(setSessionCookies);
});
test("search", async () => {
  const callback = async () => filteredSearch({ searchTerm: MOVIE_TITLE });
  await paginationTest(callback);
});

test("fanFavorites", async () => {
  await emptyArrayTestHandler(getFanFavorites);
});

test("popularTitles", async () => {
  await emptyArrayTestHandler(getPopularTitles);
});

test("getMedia", async () => {
  const media = await getMedia(SHOW_IMDB_ID);
  expect(media.title).toBeTruthy();
});

test("getReviews", async () => {
  const callback = async () => getReviews(SHOW_IMDB_ID, "", true);
  await paginationTest(callback);
});

test("getTop10Trending", async () => {
  await emptyArrayTestHandler(getTop10Trending);
});

test("getEpisodes", async () => {
  const callback = async () => getEpisodes(SHOW_IMDB_ID, 1, "");
  await paginationTest(callback);
});

test("getTop10OfAllTime", async () => {
  await emptyArrayTestHandler(getTop10OfAllTime);
});
