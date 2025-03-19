import { writable } from "svelte/store";
import type { Media, Episode } from "@/backend/imdb/types";
import {
  Resolution,
  type TorrentFile,
  type TorrentStream,
} from "@/backend/torrent/common/types";

// import sampleMedia from "@/test/results/imdb/getMedia.json";
// import sampleEpisodes from "@/test/results/imdb/getEpisodes.json";
import type { SvelteMediaTimeRange } from "svelte/elements";
import { Language } from "@ctrl/video-filename-parser";

// export let playerMedia = writable<Media | undefined>(sampleMedia as Media);
// export let playerEpisode = writable<Episode | undefined>(sampleEpisodes[0]);
export let playerMedia = writable<Media | undefined>(undefined);
export let playerEpisode = writable<Episode | undefined>(undefined);
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
 * WARN: If the user seeks, this will hold the pre-seek time until the seek request completes (e.g., if the target seek time's video data is still loading).
 * It awkwardly forwards to the the user's seek time, then immediately resets back to the pre-seek time until the seek request completes.
 */
export let currentTime = playerState(0);
export let ended = playerState(false);
export let buffered = playerState<SvelteMediaTimeRange[] | undefined>(
  undefined,
);
export let paused = playerState(true);
export let videoHeight = playerState(0);
export let videoWidth = playerState(0);
/**
 * Video watch progress, from 0 to 100.
 */
export let progress = playerState(0);
export let showControls = playerState(true);

export let volume = writable(1);
export let muted = writable(false);
export let resolution = writable(Resolution.R1080P);
export let playbackRate = writable(1);
export let video = writable<HTMLVideoElement | undefined>(undefined);
export let videoContainer = writable<HTMLDivElement | undefined>(undefined);
export let blacklistedTorrents = writable<TorrentFile[]>([]);
export let languages = writable([Language.English]);
