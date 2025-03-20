import type { EpisodeId, MediaId, SeasonEpisode } from "../imdb/types";
import type configManager from "./manager";

export type ConfigManager = typeof configManager;

export type MediaProgress = {
  id: MediaId;
  title?: string;
  time: number;
  episode?: {
    id: EpisodeId;
    title?: string;
    seasonEpisode: SeasonEpisode;
  };
};

export type Config = {
  allMediaProgress: {
    current: MediaId | undefined;
    mediaProgress: Record<MediaId, MediaProgress>;
  };
};
