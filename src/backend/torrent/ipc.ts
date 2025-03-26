import { type TorrentFile } from "./sources/common/types";
import {
  type TorrentServerConfig,
  type TorrentStream,
  GetTorrentStreamsError,
} from "./server/common/types";
import type { Episode, Media } from "@/backend/imdb/types";
// import { getTorrentsFiles as ytsGetMovieTorrentFiles } from "./yts/api";
import { getTorrentFiles as piratebayGetTorrentFiles } from "./sources/piratebay/api";
// import { getTorrentFiles as rargbGetTorrentFiles } from "./rargb/api";
// import { getTorrentFiles as solidtorrentsGetTorrentFiles } from "./rargb/api";
import {
  isSameTitle,
  parseSeason,
  seasonFormatTitle,
} from "./sources/common/functions";
import { filterMap } from "@/common/functions";
import type { Language } from "@ctrl/video-filename-parser";
import { invoke } from "@/common/ipc";

// prettier-ignore
const VIDEO_EXTS = ['3g2', '3gp', 'asf', 'avi', 'dv', 'flv', 'gxf', 'm2ts', 'm4a', 'm4b', 'm4p', 'm4r', 'm4v', 'mkv', 'mov', 'mp4', 'mpd', 'mpeg', 'mpg', 'mxf', 'nut', 'ogm', 'ogv', 'swf', 'ts', 'vob', 'webm', 'wmv', 'wtv']
const VIDEO_RX = new RegExp(`.(${VIDEO_EXTS.join("|")})$`, "i");

async function getTorrentFiles({
  media,
  episode,
  languages,
  blacklistedTorrents,
}: {
  media: Media;
  episode?: Episode;
  languages: Language[];
  blacklistedTorrents: TorrentFile[];
}): Promise<TorrentFile[]> {
  if (!media.title) throw new Error("Media title is required");
  if (!episode)
    return piratebayGetTorrentFiles({
      title: media.title,
      seasonFormattedTitle: media.title,
      isTvSeries: false,
      getCompleteSeason: false,
      mediaImdbID: media.id,
      languages,
    });
  const { abbrvSeasonTitle, fullSeasonTitle } = seasonFormatTitle(
    media.title,
    episode.seasonEpisode.seasonNumber,
    episode.seasonEpisode.episodeNumber,
  );
  const commonParams = {
    mediaImdbID: media.id,
    title: media.title,
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
        return parsedSeason?.seasonNumbers.includes(
          episode.seasonEpisode.seasonNumber,
        );
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
          parsedSeason?.seasonNumbers.includes(
            episode.seasonEpisode.seasonNumber,
          ) &&
          parsedSeason?.episodeNumbers.includes(
            episode.seasonEpisode.episodeNumber,
          )
        );
      }),
    );

  const torrentFiles = [
    ...(await seasonTorrentFilesPromise),
    ...(await episodeTorrentFilesPromise),
  ].flat();
  return torrentFiles;
}

async function getTorrentStreams(
  title: string,
  torrentFile: TorrentFile,
  isTvSeries: boolean,
): Promise<TorrentStream[]> {
  const torrentID = torrentFile.torrentID;
  const allStreams = await invoke("getTorrentStreams", torrentID);
  const videoStreams = allStreams.filter(
    ({ filename }) =>
      VIDEO_RX.test(filename) && !filename.toLowerCase().includes("sample"),
  );
  if (!videoStreams.length)
    throw new Error(GetTorrentStreamsError.NoVideoFiles);
  const torrentStreams = filterMap(videoStreams, (stream) => {
    if (!isSameTitle(title, stream.filename, isTvSeries).isSame) {
      console.warn(
        `Torrent stream did not match title "${title}"  "${stream.filename}"`,
      );
      return undefined;
    }
    if (!isTvSeries)
      return {
        ...stream,
        info: undefined,
      };
    const streamSeason = parseSeason(
      stream.filename,
      "torrentStream",
      !torrentFile.isCompleteSeason,
    );
    if (!streamSeason) {
      return undefined;
    }
    const seasonNumber = streamSeason.seasonNumbers[0];
    if (!seasonNumber) {
      console.warn("Failed to parse season number", stream.filename);
      return undefined;
    }
    const episodeNumber = streamSeason.episodeNumbers[0];
    if (!episodeNumber) {
      console.warn("Failed to parse episode number", stream.filename);
      return undefined;
    }
    return {
      ...stream,
      info: {
        seasonNumber,
        episodeNumber,
      },
    };
  });
  if (!torrentStreams.length)
    throw new Error(GetTorrentStreamsError.NoMatchingFiles);
  return torrentStreams;
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
  getTorrentStreams,
  selectTorrentStream,
  getCurrentTorrentStreamStats,
  deselectAllTorrentStreams,
  start,
};

export type TorrentIpc = typeof torrentIpc;
export default torrentIpc;
