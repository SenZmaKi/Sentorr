import { type TorrentStream, type TorrentFile, TorrentStreamsError, type TorrentStreamStats } from "./common/types";
import type { Episode, Media } from "@/backend/imdb/types";
import { getTorrentsFiles as getMovieTorrents } from "./yts/api";
import { getTorrentFiles as piratebayGetTorrentFiles } from "./piratebay/api";
// import { getTorrentFiles as rargbGetTorrentFiles } from "./rargb/api";
// import { getTorrentFiles as solidtorrentsGetTorrentFiles } from "./rargb/api";
import {
  isSameTitle,
  parseSeason,
  seasonFormatTitle,
} from "./common/functions";
import { filterMap, invokeIpc } from "@/common/functions";
import type { Language } from "@ctrl/video-filename-parser";
// prettier-ignore
const VIDEO_EXTS = ['3g2', '3gp', 'asf', 'avi', 'dv', 'flv', 'gxf', 'm2ts', 'm4a', 'm4b', 'm4p', 'm4r', 'm4v', 'mkv', 'mov', 'mp4', 'mpd', 'mpeg', 'mpg', 'mxf', 'nut', 'ogm', 'ogv', 'swf', 'ts', 'vob', 'webm', 'wmv', 'wtv']
const VIDEO_RX = new RegExp(`.(${VIDEO_EXTS.join("|")})$`, "i");

export async function getTorrentFiles({
  media,
  episode,
  languages,
  excludeTorrents,
}: {
  media: Media;
  episode?: Episode;
  languages: Language[];
  excludeTorrents: TorrentFile[];
}): Promise<TorrentFile[]> {
  if (!episode) return getMovieTorrents(media.id);
  if (!media.title) throw new Error("Media title is required");
  const { abbrvSeasonTitle, fullSeasonTitle } = seasonFormatTitle(
    media.title,
    episode.seasonNumber,
    episode.number,
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
        if (excludeTorrents.includes(torrent)) return false;
        const parsedSeason = parseSeason(
          torrent.filename,
          "torrentFile",
          false,
        );
        return parsedSeason?.seasonNumbers.includes(episode.seasonNumber);
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
        if (excludeTorrents.includes(torrent)) return false;
        const parsedSeason = parseSeason(torrent.filename, "torrentFile", true);
        return (
          parsedSeason?.seasonNumbers.includes(episode.seasonNumber) &&
          parsedSeason?.episodeNumbers.includes(episode.number)
        );
      }),
    );

  const torrentFiles = [
    ...(await seasonTorrentFilesPromise),
    ...(await episodeTorrentFilesPromise),
  ].flat();
  return torrentFiles;
}

export async function getTorrentStreams(
  title: string,
  torrentFile: TorrentFile,
  isTvSeries: boolean,
): Promise<TorrentStream[]> {
  const torrentID = torrentFile.torrentID;
  const allStreams = await invokeIpc<TorrentStream[]>("get-torrent-streams", torrentID);
  console.log("allStreams", allStreams);
  const videoStreams = allStreams.filter(
    ({ filename }) =>
      VIDEO_RX.test(filename) && !filename.toLowerCase().includes("sample"),
  );
  console.log("videoStreams", videoStreams);
  if (!videoStreams.length) throw new Error(TorrentStreamsError.NoVideoFiles);
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
  if (!torrentStreams.length) throw new Error(TorrentStreamsError.NoMatchingFiles);
  return torrentStreams;
}

export async function selectTorrentStream(torrentStream: TorrentStream) {
  return invokeIpc<void>("select-torrent-stream", torrentStream)

}

export async function getCurrentTorrentStreamStats() {
  return invokeIpc<TorrentStreamStats | undefined>("get-current-torrent-stream-stats")
}

// const magnetLink = "magnet:?xt=urn:btih:ACCD778E8EF86005A9B3E8B9407675862E306A90&dn=Mr+Robot+Season+2+Complete+720p+WEB-DL+EN-SUB+x264-%5BMULVAcoded%5D+S02&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A80&tr=udp%3A%2F%2Ftracker.zer0day.to%3A1337%2Fannounce&tr=http%3A%2F%2Fpow7.com%2Fannounce&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce&tr=udp%3A%2F%2Fp4p.arenabg.com%3A1337%2Fannounce&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969&tr=udp%3A%2F%2F9.rarbg.com%3A2710%2Fannounce&tr=udp%3A%2F%2Finferno.demonoid.pw%3A3393%2Fannounce&tr=udp%3A%2F%2Ftracker.ex.ua%3A80%2Fannounce&tr=udp%3A%2F%2F9.rarbg.me%3A2710%2Fannounce&tr=udp%3A%2F%2F9.rarbg.to%3A2710%2Fannounce&tr=udp%3A%2F%2Ftracker.ilibr.org%3A6969%2Fannounce&tr=udp%3A%2F%2Ftracker.ilibr.org%3A80%2Fannounce&tr=udp%3A%2F%2Ftracker.zer0day.to%3A1337%2Fannounce&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969%2Fannounce&tr=udp%3A%2F%2Fcoppersurfer.tk%3A6969%2Fannounce"
// Client.add(magnetLink, torrent => {
//     torrent.files.forEach(file => {
//         console.log("name", file.name)
//         console.log("stream url", file.streamURL)
//     })
// })
