import type { EpisodeId, MediaId, SeasonEpisode } from "../imdb/types";
import type { Resolution } from "../torrent/common/types";
import type { TorrentServerConfig } from "../torrent/server/common/types";
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

export type Player = {
  continueRewindSecs: number;
  resolution: Resolution;
  strictResolution: boolean;
  volume: number;
  muted: boolean;
  playbackRate: number;
};

export type Config = {
  torrent: TorrentServerConfig;
  player: Player;
  allMediaProgress: {
    current: MediaId | undefined;
    mediaProgress: Record<MediaId, MediaProgress>;
  };
};
