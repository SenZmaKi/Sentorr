import { seasonFormatTitle } from "../../../src/backend/torrent/common/functions";
import { GetTorrentFilesParams } from "../../../src/backend/torrent/common/types";
import {
  LANGUAGES,
  MOVIE_TITLE,
  SERIES_EPISODE,
  SERIES_SEASON,
  SERIES_TITLE,
} from "../../common/constants";

const commonSeriesParams = {
  languages: LANGUAGES,
  title: SERIES_TITLE,
  isTvSeries: true,
};

const epsTitles = seasonFormatTitle(
  SERIES_TITLE,
  SERIES_SEASON,
  SERIES_EPISODE,
);

export const TORRENT_EPISODE_PARAMS: GetTorrentFilesParams = {
  ...commonSeriesParams,
  seasonFormattedTitle: epsTitles.abbrvSeasonTitle,
  getCompleteSeason: false,
};

const seasonTitles = seasonFormatTitle(SERIES_TITLE, SERIES_SEASON);
export const TORRENT_SEASON_ABBRV_PARAMS: GetTorrentFilesParams = {
  ...commonSeriesParams,
  seasonFormattedTitle: seasonTitles.abbrvSeasonTitle,
  getCompleteSeason: true,
};
export const TORRENT_SEASON_FULL_PARAMS: GetTorrentFilesParams = {
  ...commonSeriesParams,
  seasonFormattedTitle: seasonTitles.fullSeasonTitle,
  getCompleteSeason: true,
};

export const TORRENT_MOVIE_PARAMS: GetTorrentFilesParams = {
  languages: LANGUAGES,
  title: MOVIE_TITLE,
  isTvSeries: false,
  seasonFormattedTitle: MOVIE_TITLE,
  getCompleteSeason: false,
};
