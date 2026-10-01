<script lang="ts">
  import TopInfoSkeleton from "./TopInfoSkeleton.svelte";
  import BottomInfoSkeleton from "./BottomInfoSkeleton.svelte";
  import SeasonsContainerSkeleton from "./SeasonsContainerSkeleton.svelte";
  export let canHaveEpisodes: boolean;
</script>

<div class="overflow-y-auto h-screen {canHaveEpisodes ? 'w-[60%]' : ''} p-2">
  <TopInfoSkeleton />
  <BottomInfoSkeleton />
</div>
{#if canHaveEpisodes}
  <div class="w-[40%]">
    <SeasonsContainerSkeleton />
  </div>
{/if}
