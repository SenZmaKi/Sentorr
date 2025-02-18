import { Language } from "@ctrl/video-filename-parser";

export type CommonTorrentFile = {
  resolution: Resolution;
  torrentID: string;
  seeders: number;
  isCompleteSeason: boolean;
  sizeBytes: number;
  dateUploadedISO: string;
};

export type YtsTorrentFile = CommonTorrentFile & {
  filename: undefined;
};
export type NormalTorrentFile = CommonTorrentFile & {
  filename: string;
};
export type TorrentFile = YtsTorrentFile | NormalTorrentFile;

export type TorrentStream = {
  filepath: string;
  filename: string;
  magnetURI: string;
  url: string;
  info?: {
    seasonNumber: number;
    episodeNumber: number;
  };
};


export enum Resolution {
  R2160P = 2160,
  R1080P = 1080,
  R720P = 720,
  R576P = 576,
  R540P = 540,
  R480P = 480,
}

export const RESOLUTIONS = Object.values(Resolution).filter(
  (value) => typeof value === "number",
);

export type GetTorrentFilesParams = {
  seasonFormattedTitle: string;
  title: string;
  getCompleteSeason: boolean;
  isTvSeries: boolean;
  languages: Language[];
};

export enum TorrentStreamsError {
  TorrentTimeout = "Torrent timeout",
  NoVideoFiles = "No video files",
  NoMatchingFiles = "No matching files",
  TorrentWasRemoved = "Torrent was removed",
}

export type TorrentStreamStats = {
  downloadSpeed: number;
  uploadSpeed: number;
  numPeers: number;

}