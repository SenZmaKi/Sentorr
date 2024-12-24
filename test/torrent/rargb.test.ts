import { getTorrentFiles } from "../../src/backend/torrent/rargb/api";
import { emptyArrayTest } from ".././common/functions";
import { test } from "bun:test";
import {
  TORRENT_EPISODE_PARAMS,
  TORRENT_MOVIE_PARAMS,
  TORRENT_SEASON_ABBRV_PARAMS,
  TORRENT_SEASON_FULL_PARAMS,
} from ".././torrent/common/constants";

test("getMovieTorrents", async () => {
  emptyArrayTest(
    "rargb:getMovieTorrents",
    await getTorrentFiles(TORRENT_MOVIE_PARAMS),
  );
});

test("getSeriesEpisodeTorrents",  async () => {
  emptyArrayTest(
    "rargb:getSeriesEpisodeTorrents",
    await getTorrentFiles(TORRENT_EPISODE_PARAMS),
  );
});

test("getSeriesFullSeasonTorrents", async () => {
  emptyArrayTest(
    "rargb:getSeriesFullSeasonTorrents",
    await getTorrentFiles(TORRENT_SEASON_FULL_PARAMS),
  );
});

test("getSeriesAbbrvSeasonTorrents", async () => {
  emptyArrayTest(
    "rargb:getAbbrvSeasonTorrents",
    await getTorrentFiles(TORRENT_SEASON_ABBRV_PARAMS),
  );
});
