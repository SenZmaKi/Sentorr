<script lang="ts">
  import type { Media } from "$backend/imdb/types";
  import Season from "./Season.svelte";
  export let media: Media;
</script>

<div class="w-1/3 ml-2 overflow-y-auto">
  {#if media.seasonsCount}
    {#each Array.from({ length: media.seasonsCount }, (_, i) => ++i) as seasonNumber}
      <Season mediaID={media.id} {seasonNumber} />
    {/each}
  {/if}
</div>
