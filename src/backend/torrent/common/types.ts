import { Language, Resolution } from "@ctrl/video-filename-parser";

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

export type GetTorrentFilesParams = {
  seasonFormattedTitle: string;
  title: string;
  getCompleteSeason: boolean;
  isTvSeries: boolean;
  languages: Language[];
};

