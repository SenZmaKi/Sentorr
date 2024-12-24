import { getTorrentsFiles } from "../../src/backend/torrent/yts/api.js";
import { emptyArrayTest } from ".././common/functions.js";
import { MOVIE_IMDB_ID } from ".././common/constants.js";
//@ts-ignore
import { test } from "bun:test";

test("getMovieTorrents", async () => {
  emptyArrayTest("yts:getMovieTorrents", await getTorrentsFiles(MOVIE_IMDB_ID));
});