<script lang="ts">
  import TopInfo from "./TopInfo.svelte";
  import BottomInfo from "./BottomInfo.svelte";
  import { switchToSearchPage } from "../common/functions";
  import SeasonsContainer from "./SeasonsContainer.svelte";
  import { previewMedia, previewResult } from "../common/store";
  import PreviewSkeleton from "./PreviewSkeleton.svelte";
  import PageWrapper from "../common/PageWrapper.svelte";
  export let hidden: boolean;
</script>

{#if $previewMedia && $previewResult}
  <PageWrapper {hidden}>
    {#await $previewMedia}
      <PreviewSkeleton isMovie={$previewResult.isMovie} />
    {:then media}
      <div class="flex max-h-screen">
        <div class="overflow-y-auto {!media.isMovie ? 'w-2/3' : ''} p-2">
          <!-- TODO: Make this prettier -->
          <button on:click={switchToSearchPage}>Search</button>
          <TopInfo {media} />
          <BottomInfo {media} />
        </div>
        {#if !media.isMovie}
          <SeasonsContainer {media} />
        {/if}
      </div>
    {/await}
  </PageWrapper>
{/if}
