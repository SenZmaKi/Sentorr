<script lang="ts">
  import { getEpisodes } from "@/backend/imdb/api";
  import type { Episode as EpisodeType, Media } from "@/backend/imdb/types";
  import type { Writable } from "svelte/store";
  import { createInfiniteScrollStore } from "../common/functions";
  import Episode from "./Episode.svelte";
  import EpisodeSkeleton from "./EpisodeSkeleton.svelte";
  import { getCurrentMediaProgress } from "../common/store";
  export let seasonNumber: number;
  export let media: Media;

  const currentMediaProgress = getCurrentMediaProgress();
  let open =
    seasonNumber ===
    (currentMediaProgress?.episode?.seasonEpisode.seasonNumber ?? 1);
  let accumulatedResults: Writable<(EpisodeType | undefined)[]>;
  let infiniteScroll: (event: Event | null) => Promise<void>;
  let wasOpened = false;
  $: if (open && !wasOpened) {
    [accumulatedResults, infiniteScroll] = createInfiniteScrollStore(
      (nextPageKey) => getEpisodes(media.id, seasonNumber, nextPageKey),
      false,
      10,
    );
    wasOpened = true;
  }
</script>

<div>
  <button on:click={() => (open = !open)}>
    <div
      class="xxs-dark min-w-[250px] shadow-lg rounded p-2 mt-2 flex justify-between items-center"
    >
      <span class="font-semibold pr-2" style="font-size: 40px;">
        Season {seasonNumber}
      </span>
      <svg
        class="w-[40px] h-[40px]"
        style="transform: rotate({open ? '180deg' : '0deg'});
        transition: transform 0.3s ease;"
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 448 512"
      >
        <path
          d="M201.4 374.6c12.5 12.5 32.8 12.5 45.3 0l160-160c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L224 306.7 86.6 169.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3l160 160z"
        ></path>
      </svg>
    </div>
  </button>
  {#if open}
    <div
      class="overflow-y-auto h-[700px] w-[98%] items-center"
      on:scroll={infiniteScroll}
    >
      {#each $accumulatedResults as episode}
        {#if episode}
          <Episode {episode} {media} />
        {:else}
          <EpisodeSkeleton />
        {/if}
      {/each}
    </div>
  {/if}
</div>
