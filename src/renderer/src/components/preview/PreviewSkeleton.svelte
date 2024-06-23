<script lang="ts">
  import TopInfoSkeleton from "./TopInfoSkeleton.svelte";
  import BottomInfoSkeleton from "./BottomInfoSkeleton.svelte";
  import { switchToSearchPage } from "../common/functions";
  import SeasonsContainerSkeleton from "./SeasonsContainerSkeleton.svelte";
  export let isMovie: boolean;
</script>

<div class="flex max-h-screen">
  <div class="overflow-y-auto {!isMovie ? 'w-2/3' : ''} p-2">
    <button on:click={switchToSearchPage}>Search</button>
    <TopInfoSkeleton />
    <BottomInfoSkeleton />
  </div>
  {#if !isMovie}
    <SeasonsContainerSkeleton />
  {/if}
</div>
