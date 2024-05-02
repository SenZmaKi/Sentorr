import { getTorrents } from "../src/backend/yts/api.js";
import { emptyArrayTest } from "./common/functions.js";
import { MOVIE_IMDB_ID } from "./common/constants.js";
import { test } from "bun:test";

test("getTorrents", async () => {
  emptyArrayTest("getTorrents", await getTorrents(MOVIE_IMDB_ID));
});
