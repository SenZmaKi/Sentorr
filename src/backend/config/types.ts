import type { EpisodeId, MediaId, SeasonEpisode } from "../imdb/types";
import type configManager from "./manager";

export type ConfigManager = typeof configManager;

type WatchTime = {
  currentTime: number;
  duration: number;
};

export type MediaProgress = {
  id: MediaId;
  title?: string;
  watchTime: WatchTime;
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
