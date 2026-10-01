import { getTorrentFiles } from "@/backend/torrent/sources/rargb/api";
import { failIfEmpty } from "@/test/common/functions";
import { test } from "bun:test";
import {
  TORRENT_EPISODE_PARAMS,
  TORRENT_MOVIE_PARAMS,
  TORRENT_SEASON_ABBRV_PARAMS,
  TORRENT_SEASON_FULL_PARAMS,
} from "@/test/torrent/common/constants";

test("getMovieTorrents", async () => {
  await failIfEmpty(
    "torrent/rargb/getMovieTorrents",
    await getTorrentFiles(TORRENT_MOVIE_PARAMS),
  );
});

test("getSeriesEpisodeTorrents", async () => {
  await failIfEmpty(
    "torrent/rargb/getSeriesEpisodeTorrents",
    await getTorrentFiles(TORRENT_EPISODE_PARAMS),
  );
});

test("getSeriesFullSeasonTorrents", async () => {
  await failIfEmpty(
    "torrent/rargb/getSeriesFullSeasonTorrents",
    await getTorrentFiles(TORRENT_SEASON_FULL_PARAMS),
  );
});

test("getSeriesAbbrvSeasonTorrents", async () => {
  await failIfEmpty(
    "torrent/rargb/getAbbrvSeasonTorrents",
    await getTorrentFiles(TORRENT_SEASON_ABBRV_PARAMS),
  );
});
