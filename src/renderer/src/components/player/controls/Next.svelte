<script lang="ts">
  import { type Episode, type Media } from "@/backend/imdb/types";
  import Button from "./Button.svelte";
  import { randomNumber } from "@/common/functions";
  import { playerMedia, playerEpisode } from "../store";
  import { getEpisodes, getFanFavorites, getMedia } from "@/backend/imdb/api";
  import { toast } from "svelte-sonner";

  async function getNextEpisode() {
    if (!$playerEpisode || !$playerMedia) return;

    let nextPageKey: string | undefined = undefined;
    let nextEpisode: Episode | undefined = undefined;
    while (true) {
      const pagination = await getEpisodes(
        $playerMedia.id,
        $playerEpisode.seasonNumber
      );
      nextEpisode = pagination.results.find(
        (episode) =>
          $playerEpisode && $playerEpisode.number + 1 === episode.number
      );
      if (nextEpisode) break;
      nextPageKey = pagination.nextPageKey;
      if (!nextPageKey) {
        if (
          $playerMedia.seasonsCount &&
          $playerMedia.seasonsCount < $playerEpisode.seasonNumber + 1
        )
          break;
        const pagination = await getEpisodes(
          $playerMedia.id,
          $playerEpisode.seasonNumber + 1
        );
        nextEpisode = pagination.results[0];
        break;
      }
    }
    return nextEpisode;
  }

  async function getNextMedia() {
    if (!$playerMedia) return;

    const recommendations = $playerMedia.recommendations?.length
      ? $playerMedia.recommendations
      : await getFanFavorites();

    if (!recommendations.length) return undefined;
    const randomIdx = randomNumber({
      max: recommendations.length - 1,
    });
    const randomRecommendation = recommendations[randomIdx];
    const nextMedia = await getMedia(randomRecommendation.id);
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

  async function onClick() {
    console.log("Next clicked");
    if (!$playerEpisode) {
      const nextMedia = await getNextMedia();
      console.log("Next media:", nextMedia?.title);
      setNextMedia(nextMedia);
    } else {
      const nextEpisode = await getNextEpisode();
      console.log(
        `Next episode: S${nextEpisode?.seasonNumber} E${nextEpisode?.number}`
      );
      if (nextEpisode) {
        $playerEpisode = nextEpisode;
      } else {
        toast.info("No more episodes available", {
          description:
            "Already at the latest episode, picking a recommendation instead",
        });
        const nextMedia = await getNextMedia();
        setNextMedia(nextMedia);
      }
    }
  }
</script>

<Button {onClick}>
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
</Button>

<div></div>
