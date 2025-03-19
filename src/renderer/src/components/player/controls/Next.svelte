<script lang="ts">
  import { type Episode, type Media } from "@/backend/imdb/types";
  import Button from "./Button.svelte";
  import { randomNumber, zfill } from "@/common/functions";

  import {
    playerMedia,
    playerEpisode,
    playerTorrentStream,
    ended,
    progress,
    languages,
    blacklistedTorrents,
  } from "../common/store";
  import { getEpisodes, getFanFavorites, getMedia } from "@/backend/imdb/api";
  import { toast } from "svelte-sonner";

  async function prefetchNextTorrentFiles() {
    hasPrefetched = true;
    console.log("prefetchNextTorrentFiles()");
    const nextEpisode = await nextEpisodePromise;
    const nextMedia = await nextMediaPromise;
    const media = nextEpisode ? $playerMedia : nextMedia;
    if (!nextEpisode || !media) return;
    // Relies on the caching at the net client level
    // TODO: Remove double work since getTorrentFiles will reprocess the torrent files at Player.svelte:load()
    // TODO: Use a better way to prefetch torrent files as oppossed to relying on the caching at the net client level
    await window.ipc.torrent.getTorrentFiles({
      media,
      episode: nextEpisode,
      languages: $languages,
      blacklistedTorrents: $blacklistedTorrents,
    });
  }

  async function getNextEpisode(episode: Episode, media: Media) {
    let nextPageKey: string | undefined = undefined;
    let nextEpisode: Episode | undefined = undefined;
    while (true) {
      const pagination = await getEpisodes(media.id, episode.seasonNumber);
      nextEpisode = pagination.results.find(
        (episode) =>
          $playerEpisode && $playerEpisode.number + 1 === episode.number,
      );
      if (nextEpisode) break;
      nextPageKey = pagination.nextPageKey;
      if (!nextPageKey) {
        if (media.seasonsCount && media.seasonsCount < episode.seasonNumber + 1)
          break;
        const pagination = await getEpisodes(
          media.id,
          episode.seasonNumber + 1,
        );
        nextEpisode = pagination.results[0];
        break;
      }
    }
    if (nextEpisode)
      console.log(
        `Next episode: ${media.title} S${nextEpisode.seasonNumber}E${nextEpisode.number}`,
        nextEpisode,
      );
    return nextEpisode;
  }

  async function getNextMedia(media: Media) {
    const recommendations = media.recommendations?.length
      ? media.recommendations
      : await getFanFavorites();

    if (!recommendations.length) return undefined;
    const randomIdx = randomNumber({
      max: recommendations.length - 1,
    });
    const randomRecommendation = recommendations[randomIdx];
    const nextMedia = await getMedia(randomRecommendation.id);
    if (nextMedia) console.log(`Next media: ${nextMedia.title}`, nextMedia);
    return nextMedia;
  }

  function setNextMedia(nextMedia: Media | undefined) {
    if (nextMedia) {
      toast.info("Now playing", {
        description: nextMedia.title,
      });
    } else {
      toast.error("No recommendations found", {
        description: "Try picking one yourself",
      });
    }
  }

  async function next() {
    console.log("next()");
    if (!$playerEpisode) {
      const nextMedia = await nextMediaPromise;
      setNextMedia(nextMedia);
    } else {
      const nextEpisode = await nextEpisodePromise;
      if (nextEpisode) {
        $playerEpisode = nextEpisode;
      } else {
        toast.info("No more episodes available", {
          description:
            "Already at the latest episode, picking a recommendation instead",
        });
        const nextMedia = await nextMediaPromise;
        setNextMedia(nextMedia);
      }
    }
  }

  let nextStr = "Loading...";
  async function setNextStr(
    nextMediaPromise: Promise<Media | undefined>,
    nextEpisodePromise: Promise<Episode | undefined>,
  ): Promise<void> {
    const nextMedia = await nextMediaPromise;
    const nextEpisode = await nextEpisodePromise;
    if ($playerEpisode) {
      nextStr = nextEpisode
        ? `S${zfill(nextEpisode.seasonNumber)}:E${zfill(nextEpisode.number)}${nextEpisode.title ? ` ${nextEpisode.title}` : ""}`
        : "No more episodes available";
    } else {
      nextStr = nextMedia
        ? nextMedia.title ?? "No media title"
        : "No recommendations found";
    }
  }

  let hasPrefetched = false;
  $: if ($playerTorrentStream) hasPrefetched = false;
  $: if (!hasPrefetched && $progress >= 80) prefetchNextTorrentFiles();

  $: nextMediaPromise = $playerMedia && getNextMedia($playerMedia);
  $: nextEpisodePromise =
    $playerEpisode &&
    $playerMedia &&
    getNextEpisode($playerEpisode, $playerMedia);

  $: if ($ended) {
    next();
  }
  $: nextMediaPromise &&
    nextEpisodePromise &&
    setNextStr(nextMediaPromise, nextEpisodePromise);
</script>

<Button onClick={next}>
  <div>
    <svg
      fill="#ffffff"
      version="1.1"
      id="Capa_1"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      viewBox="0 0 51.531 51.531"
      xml:space="preserve"
      ><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g
        id="SVGRepo_tracerCarrier"
        stroke-linecap="round"
        stroke-linejoin="round"
      ></g><g id="SVGRepo_iconCarrier">
        <g>
          <path
            d="M44.9,1.963c-3.662,0-6.631,2.969-6.631,6.631V23.81c-0.285-0.324-0.617-0.609-1-0.831L6,4.926 c-1.238-0.715-2.762-0.715-4,0C0.763,5.64,0,6.961,0,8.39v36.104c0,1.43,0.763,2.75,2,3.465c0.619,0.356,1.311,0.535,2,0.535 c0.691,0,1.381-0.179,2-0.535l31.269-18.053c0.383-0.223,0.715-0.508,1-0.832v13.863c0,3.662,2.969,6.631,6.631,6.631 s6.631-2.969,6.631-6.631V8.594C51.531,4.932,48.562,1.963,44.9,1.963z"
          ></path>
        </g>
      </g></svg
    >
  </div>
</Button>
