import { getTorrentFiles } from "@/backend/torrent/sources/piratebay/api";
import { failIfEmpty } from "@/test/common/functions";
import { test } from "bun:test";
import {
  TORRENT_EPISODE_PARAMS,
  TORRENT_MOVIE_PARAMS,
  TORRENT_SEASON_ABBRV_PARAMS,
  TORRENT_SEASON_FULL_PARAMS,
} from "./common/constants";
import {
  MOVIE_IMDB_ID,
  SHOW_IMDB_ID,
  EPISODE_IMDB_ID,
} from "@/test/common/constants";

test("getMovieTorrents", async () => {
  await failIfEmpty(
    "torrent/piratebay/getMovieTorrents",
    await getTorrentFiles({
      ...TORRENT_MOVIE_PARAMS,
      mediaImdbID: MOVIE_IMDB_ID,
    }),
  );
});

test("getSeriesEpisodeTorrents", async () => {
  await failIfEmpty(
    "torrent/piratebay/getSeriesEpisodeTorrents",
    await getTorrentFiles({
      ...TORRENT_EPISODE_PARAMS,
      mediaImdbID: SHOW_IMDB_ID,
      episodeImdbID: EPISODE_IMDB_ID,
    }),
  );
});

test("getSeriesAbbrvSeasonTorrents", async () => {
  await failIfEmpty(
    "torrent/piratebay/getSeriesAbbrvSeasonTorrents",
    await getTorrentFiles({
      ...TORRENT_SEASON_ABBRV_PARAMS,
      mediaImdbID: SHOW_IMDB_ID,
      episodeImdbID: EPISODE_IMDB_ID,
    }),
  );
});

test("getSeriesFullSeasonTorrents", async () => {
  await failIfEmpty(
    "torrent/piratebay/getSeriesFullSeasonTorrents",
    await getTorrentFiles({
      ...TORRENT_SEASON_FULL_PARAMS,
      mediaImdbID: SHOW_IMDB_ID,
      episodeImdbID: EPISODE_IMDB_ID,
    }),
  );
});
