import { getTorrents } from "../src/backend/yts-api/yts-api.js";
import { emptyArrayTest } from "./utils/functions.js";
import { MOVIE_IMDB_ID } from "./utils/constants.js";

test("getTorrents", async () => {
  emptyArrayTest(await getTorrents(MOVIE_IMDB_ID));
});
