import { get, writable } from "svelte/store";
import type { Media, Episode } from "@/backend/imdb/types";
import { type TorrentFile } from "@/backend/torrent/sources/common/types";
import { type TorrentStream } from "@/backend/torrent/server/common/types";
import { type Config } from "@/backend/config/types";
// import sampleMedia from "@/test/results/imdb/getMedia.json";
// import sampleEpisodes from "@/test/results/imdb/getEpisodes.json";
import type { SvelteMediaTimeRange } from "svelte/elements";
import { Language } from "@ctrl/video-filename-parser";
import { getCurrentMediaProgress } from "../../common/store";
import { getMedia, getEpisode } from "@/backend/imdb/api";
import { config } from "../../common/store";

async function setProgress() {
  const mediaProgress = getCurrentMediaProgress();
  if (!mediaProgress) return;
  const episodePromise =
    mediaProgress.episode && getEpisode(mediaProgress.episode.id);
  const mediaPromise = getMedia(mediaProgress.id);
  if (episodePromise) playerEpisode.set(await episodePromise);
  playerMedia.set(await mediaPromise);
}
// export let playerMedia = writable<Media | undefined>(sampleMedia as Media);
// export let playerEpisode = writable<Episode | undefined>(sampleEpisodes[0]);
/**
 *WARN: Whenever updating `playerMedia` and `playerEpisode`, update `playerEpisode` first.
 * This is because truthy `playerMedia` and `undefined`` `playerEpisode` triggers Player.load() i.e., when Media.canHaveEpisodes is false.
 */
export let playerMedia = writable<Media | undefined>(undefined);
/**
 *WARN: Whenever updating `playerMedia` and `playerEpisode`, update `playerEpisode` first.
 * This is because truthy `playerMedia` and `undefined` `playerEpisode` triggers Player.load() i.e., when `Media.canHaveEpisodes` is `false`.
 */
export let playerEpisode = writable<Episode | undefined>(undefined);
setProgress();

/**
 * State that is set to `defaultValue` when the currently playing content changes i.e., `playerMedia` or `playerEpisode` changes.
 */
function playerState<T>(defaultValue: T) {
  const store = writable<T>(defaultValue);
  playerMedia.subscribe(() => store.set(defaultValue));
  playerEpisode.subscribe(() => store.set(defaultValue));
  return store;
}
export let playerTorrentFile = playerState<TorrentFile | undefined>(undefined);
export let playerTorrentStream = playerState<TorrentStream | undefined>(
  undefined,
);
export let duration = playerState(0);
/**
 * WARN: DON'T bind this to `video.currentTime`, weird playback things happen.
 * For instance on pause, the video pauses then moves forward by one frame and then really pauses at that.
 * Might be because of floating point precision errors
 */
export let currentTime = playerState(0);
export let ended = playerState(false);
export let buffered = playerState<SvelteMediaTimeRange[] | undefined>(
  undefined,
);
export let paused = playerState(true);
export let videoHeight = playerState(0);
export let videoWidth = playerState(0);
export let src = playerState("");
/**
 * Video watch progress, from 0 to 100.
 */
export let progress = playerState(0);
export let showControls = playerState(true);

function configState<Key extends keyof Config["player"]>(key: Key) {
  const value = get(config).player[key];
  const store = writable(value);
  let isInitialRun = true;
  store.subscribe((newValue) => {
    if (isInitialRun) {
      isInitialRun = false;
      return;
    }
    config.update((config) => ({
      ...config,
      player: { ...config.player, [key]: newValue },
    }));
  });
  return store;
}

export let volume = configState("volume");
export let muted = configState("muted");
export let resolution = configState("resolution");
export let strictResolution = configState("strictResolution");
export let playbackRate = configState("playbackRate");
export let blacklistedTorrents = writable<TorrentFile[]>([]);
export let languages = writable([Language.English]);

export let video = writable<HTMLVideoElement | undefined>(undefined);
export let videoContainer = writable<HTMLDivElement | undefined>(undefined);
export let useMiniplayer = writable(false);
