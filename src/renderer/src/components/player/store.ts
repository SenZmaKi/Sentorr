import { writable } from "svelte/store";
import type { Media, Episode } from "@/backend/imdb/types";
import type { TorrentFile, TorrentStream } from "@/backend/torrent/common/types";

import sampleMedia from "@/test-results/imdb/getMedia.json";
import sampleEpisodes from "@/test-results/imdb/getEpisodes.json";

export let playerMedia = writable<Media | undefined>(sampleMedia as Media);
export let playerEpisode = writable<Episode | undefined>(sampleEpisodes[0]);
export let playerTorrentFile = writable<TorrentFile | undefined>(undefined);
export let playerTorrentStream = writable<TorrentStream | undefined>(undefined);