import { writable } from "svelte/store";
import type { Media, Episode } from "@/backend/imdb/types";
import {
  Resolution,
  type TorrentFile,
  type TorrentStream,
} from "@/backend/torrent/common/types";

import sampleMedia from "@/test/results/imdb/getMedia.json";
import sampleEpisodes from "@/test/results/imdb/getEpisodes.json";
import type { SvelteMediaTimeRange } from "svelte/elements";

export let playerMedia = writable<Media | undefined>(sampleMedia as Media);
export let playerEpisode = writable<Episode | undefined>(sampleEpisodes[0]);
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
export let currentTime = playerState(0);
export let buffered = playerState<SvelteMediaTimeRange[] | undefined>(
  undefined,
);
export let paused = playerState(true);
export let videoHeight = playerState(0);
export let videoWidth = playerState(0);

export let volume = writable(1);
export let muted = writable(false);
export let resolution = writable(Resolution.R1080P);
export let playbackRate = writable(1);
export let video = writable<HTMLVideoElement | undefined>(undefined);
