<script lang="ts">
  import type { Media } from "$backend/imdb/types";
  import Season from "./Season.svelte";
  export let media: Media;
</script>

<div class="w-[600px]">
  {#if media.seasonsCount}
    {#each Array.from({ length: media.seasonsCount }, (_, i) => ++i) as seasonNumber}
      <div class="mb-2">
        <Season mediaID={media.id} {seasonNumber} />
      </div>
    {/each}
  {/if}
</div>
