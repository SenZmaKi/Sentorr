
import { getTorrentFiles } from "../../src/backend/torrent/solidtorrents//api";
import { emptyArrayTest } from ".././common/functions";
// @ts-ignore
import { test } from "bun:test";
import {
  TORRENT_EPISODE_PARAMS,
  TORRENT_MOVIE_PARAMS,
  TORRENT_SEASON_ABBRV_PARAMS,
  TORRENT_SEASON_FULL_PARAMS,
} from ".././torrent/common/constants";

test("getMovieTorrents", async () => {
  emptyArrayTest(
    "getMovieTorrents",
    await getTorrentFiles(TORRENT_MOVIE_PARAMS),
  );
});

test("getSeriesEpisodeTorrents", async () => {
  emptyArrayTest(
    "getSeriesEpisodeTorrents",
    await getTorrentFiles(TORRENT_EPISODE_PARAMS),
  );
});

test("getSeriesFullSeasonTorrents", async () => {
  emptyArrayTest(
    "getSeriesFullSeasonTorrents",
    await getTorrentFiles(TORRENT_SEASON_FULL_PARAMS),
  );
});

test("getSeriesAbbrvSeasonTorrents", async () => {
  emptyArrayTest(
    "getSeriesAbbrvTorrents",
    await getTorrentFiles(TORRENT_SEASON_ABBRV_PARAMS),
  );
});
