<script lang="ts">
    import { getEpisodes } from "$backend/imdb/api";
  import type { Episode as EpisodeType } from "$backend/imdb/types";
    import type { Writable } from "svelte/store";
    import { createInfiniteScrollStore } from "../common/functions";
  import Episode from "./Episode.svelte";
  import EpisodeSkeleton from "./EpisodeSkeleton.svelte";


  export let seasonNumber: number;
  export let mediaID: string;
  let open = seasonNumber === 1;
  let accumulatedResults: Writable<(EpisodeType | undefined)[]>
  let infiniteScroll: (event: Event | null) => Promise<void>;
  let wasOpened = false;
  $: if (open && !wasOpened) {
    [accumulatedResults, infiniteScroll ] = createInfiniteScrollStore((nextPageKey) => getEpisodes(mediaID, seasonNumber, nextPageKey), false, 10);
    wasOpened = true;
}

</script>
<div class="mb-4">
  <button on:click={() => open = !open}>
    <div class="xxs-dark shadow-lg rounded w-[500px] p-2 mb-4 flex justify-between h-[50px] align-bottom" >
        <span class="font-semibold text-3xl">
        Season {seasonNumber}
      </span>
      <svg class="w-[40px] h-[40px]" class:rotate-180={open}  xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512">
			<path d="M201.4 374.6c12.5 12.5 32.8 12.5 45.3 0l160-160c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L224 306.7 86.6 169.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3l160 160z"></path>
		</svg>
    </div>
  </button>
  {#if open}
    <div class="overflow-y-auto h-[700px] items-center " on:scroll={infiniteScroll}>
      {#each $accumulatedResults as episode}
          {#if episode}
            <Episode {episode}/>
          {:else}
            <EpisodeSkeleton/>
          {/if}
      {/each}
    </div>
  {/if}
</div>
