import { getTorrents } from "../src/backend/yts/api.js";
import { emptyArrayTest } from "./utils/functions.js";
import { MOVIE_IMDB_ID } from "./utils/constants.js";
import { test } from "bun:test";

test("getTorrents", async () => {
  emptyArrayTest(await getTorrents(MOVIE_IMDB_ID));
});
