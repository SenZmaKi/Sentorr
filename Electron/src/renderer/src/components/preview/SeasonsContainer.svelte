<script lang="ts">
  import type { Media } from "@/backend/imdb/types";
  import Season from "./Season.svelte";
  import type { MediaProgress } from "@/backend/config/types";
  export let media: Media;
  export let mediaProgress: MediaProgress | undefined = undefined;
</script>

<div class="w-full ml-2 overflow-y-auto h-screen">
  {#if media.seasonsCount}
    {#each Array.from({ length: media.seasonsCount }, (_, i) => ++i) as seasonNumber}
      <Season {media} {mediaProgress} {seasonNumber} />
    {/each}
  {/if}
  <div class="h-[10px]"></div>
</div>
