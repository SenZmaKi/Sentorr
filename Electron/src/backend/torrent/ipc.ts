import { type TorrentFile } from "./sources/common/types";
import {
  type TorrentServerConfig,
  type TorrentStream,
  GetTorrentStreamError,
} from "./server/common/types";
import type { Episode, Media, SeasonEpisode } from "@/backend/imdb/types";
// import { getTorrentsFiles as ytsGetMovieTorrentFiles } from "./yts/api";
import { getTorrentFiles as piratebayGetTorrentFiles } from "./sources/piratebay/api";
// import { getTorrentFiles as rargbGetTorrentFiles } from "./rargb/api";
// import { getTorrentFiles as solidtorrentsGetTorrentFiles } from "./rargb/api";
import {
  isSameTitle,
  parseSeason,
  seasonFormatTitle,
} from "./sources/common/functions";
import type { Language } from "@ctrl/video-filename-parser";
import { invoke } from "@/common/ipc";

// prettier-ignore
const VIDEO_EXTS = ['3g2', '3gp', 'asf', 'avi', 'dv', 'flv', 'gxf', 'm2ts', 'm4a', 'm4b', 'm4p', 'm4r', 'm4v', 'mkv', 'mov', 'mp4', 'mpd', 'mpeg', 'mpg', 'mxf', 'nut', 'ogm', 'ogv', 'swf', 'ts', 'vob', 'webm', 'wmv', 'wtv']
const VIDEO_RX = new RegExp(`.(${VIDEO_EXTS.join("|")})$`, "i");

async function getTorrentFiles({
  mediaImdbID,
  episodeImdbID,
  title,
  seasonEpisode,
  languages,
  blacklistedTorrents,
}: {
  mediaImdbID: string;
  episodeImdbID: string | undefined;
  title: string;
  seasonEpisode: SeasonEpisode | undefined;
  languages: Language[];
  blacklistedTorrents: TorrentFile[];
}): Promise<TorrentFile[]> {
  if (!seasonEpisode)
    return piratebayGetTorrentFiles({
      title,
      seasonFormattedTitle: title,
      isTvSeries: false,
      getCompleteSeason: false,
      mediaImdbID,
      episodeImdbID,
      languages,
    });
  const { abbrvSeasonTitle, fullSeasonTitle } = seasonFormatTitle(
    title,
    seasonEpisode.seasonNumber,
    seasonEpisode.episodeNumber,
  );
  const commonParams = {
    mediaImdbID,
    episodeImdbID,
    title,
    isTvSeries: true,
    languages: languages,
  };
  const seasonTorrentFilesPromise = Promise.all([
    piratebayGetTorrentFiles({
      ...commonParams,
      seasonFormattedTitle: abbrvSeasonTitle,
      getCompleteSeason: true,
    }),
    piratebayGetTorrentFiles({
      ...commonParams,
      seasonFormattedTitle: fullSeasonTitle,
      getCompleteSeason: true,
    }),
  ])
    .then((results) => results.flat())
    .then((results) =>
      results.filter((torrent) => {
        if (
          blacklistedTorrents.find((et) => et.torrentID === torrent.torrentID)
        )
          return false;
        const parsedSeason = parseSeason(
          torrent.filename,
          "torrentFile",
          false,
        );
        return parsedSeason?.seasonNumbers.includes(seasonEpisode.seasonNumber);
      }),
    );

  const episodeTorrentFilesPromise = Promise.all([
    piratebayGetTorrentFiles({
      ...commonParams,
      seasonFormattedTitle: abbrvSeasonTitle,
      getCompleteSeason: false,
    }),
    piratebayGetTorrentFiles({
      ...commonParams,
      seasonFormattedTitle: fullSeasonTitle,
      getCompleteSeason: false,
    }),
  ])
    .then((results) => results.flat())
    .then((results) =>
      results.filter((torrent) => {
        if (
          blacklistedTorrents.find((et) => et.torrentID === torrent.torrentID)
        )
          return false;
        const parsedSeason = parseSeason(torrent.filename, "torrentFile", true);
        return (
          parsedSeason?.seasonNumbers.includes(seasonEpisode.seasonNumber) &&
          parsedSeason?.episodeNumbers.includes(seasonEpisode.episodeNumber)
        );
      }),
    );

  const torrentFiles = [
    ...(await seasonTorrentFilesPromise),
    ...(await episodeTorrentFilesPromise),
  ].flat();
  return torrentFiles;
}

async function getTorrentStream(
  title: string,
  torrentFile: TorrentFile,
  seasonEpisode: SeasonEpisode | undefined,
): Promise<TorrentStream> {
  const torrentID = torrentFile.torrentID;
  const allStreams = await invoke("getTorrentStreams", torrentID);
  const isTvSeries = !!seasonEpisode;
  const matchingStream = allStreams
    .filter(
      ({ filename }) =>
        VIDEO_RX.test(filename) && !filename.toLowerCase().includes("sample"),
    )
    .find((torrentStream) => {
      if (!isSameTitle(title, torrentStream.filename, isTvSeries).isSame) {
        console.warn(
          `Torrent stream did not match title "${title}"  "${torrentStream.filename}"`,
        );
        return undefined;
      }
      if (!isTvSeries) return true;
      const streamSeason = parseSeason(
        torrentStream.filename,
        "torrentStream",
        !torrentFile.isCompleteSeason,
      );
      if (!streamSeason) return false;
      const seasonNumber = streamSeason.seasonNumbers[0];
      if (!seasonNumber) {
        console.warn("Failed to parse season number", torrentStream.filename);
        return false;
      }
      const episodeNumber = streamSeason.episodeNumbers[0];
      if (!episodeNumber) {
        console.warn("Failed to parse episode number", torrentStream.filename);
        return false;
      }
      return (
        seasonNumber === seasonEpisode.seasonNumber &&
        episodeNumber === seasonEpisode.episodeNumber
      );
    });
  if (!matchingStream) throw new Error(GetTorrentStreamError.NoMatchingFile);
  return matchingStream;
}

async function selectTorrentStream(torrentStream: TorrentStream) {
  return await invoke("selectTorrentStream", torrentStream);
}

async function getCurrentTorrentStreamStats() {
  return await invoke("getCurrentTorrentStreamStats");
}

async function deselectAllTorrentStreams() {
  return await invoke("deselectAllTorrentStreams");
}

async function start(config: TorrentServerConfig) {
  return await invoke("start", config);
}

const torrentIpc = {
  getTorrentFiles,
  getTorrentStream,
  selectTorrentStream,
  getCurrentTorrentStreamStats,
  deselectAllTorrentStreams,
  start,
};

export type TorrentIpc = typeof torrentIpc;
export default torrentIpc;
