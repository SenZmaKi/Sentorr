import {
  getMovieTorrents,
  getSeriesTorrents,
} from "../src/backend/rargb/api.js";
import {
  MOVIE_TITLE,
  SERIES_EPISODE,
  SERIES_SEASON,
  SERIES_TITLE,
} from "./utils/constants.js";
import { emptyArrayTest } from "./utils/functions.js";
import { test } from "bun:test";

test("getMovieTorrents", async () => {
  emptyArrayTest("getMovieTorrents", await getMovieTorrents(MOVIE_TITLE));
});

test("getSeriesEpisodeTorrents", async () => {
  emptyArrayTest(
    "getSeriesEpisodeTorrents",
    await getSeriesTorrents("", SERIES_TITLE, SERIES_SEASON, SERIES_EPISODE),
  );
});

test("getSeriesSeasonTorrents", async () => {
  emptyArrayTest(
    "getSeriesSeasonTorrents",
    await getSeriesTorrents(SERIES_TITLE, SERIES_SEASON, undefined),
  );
});
