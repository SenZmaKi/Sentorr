import { Language } from "@ctrl/video-filename-parser";

export type TorrentFile = {
  filename?: string;
  resolution: Resolution;
  torrentID: string;
  seeders: number;
  isCompleteSeason: boolean;
  size: string;
  dateUploaded: string;
};

export type TorrentStream = {
  filename: string;
  url: string;
  info?: {
    seasonNumber?: number;
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

export type GetTorrentFilesParams = {
  seasonFormattedTitle: string;
  title: string;
  getCompleteSeason: boolean;
  isTvSeries: boolean;
  languages: Language[];
};

