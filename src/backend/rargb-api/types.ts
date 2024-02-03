import * as vfp from "@ctrl/video-filename-parser";

export type Torrent = {
  title: string;
  resolution: vfp.Resolution;
  magnetLink: string;
  seeders: number;
  isCompleteSeason: boolean;
};
