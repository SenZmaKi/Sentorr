<script lang="ts">
  import TopInfo from "./TopInfo.svelte";
  import BottomInfo from "./BottomInfo.svelte";
  import SeasonsContainer from "./SeasonsContainer.svelte";
  import {
    getMediaProgress,
    previewMedia,
    previewResult,
  } from "../common/store";
  import PreviewSkeleton from "./PreviewSkeleton.svelte";
  import PageWrapper from "../common/PageWrapper.svelte";
  import type { Media } from "@/backend/imdb/types";
  import type { MediaProgress } from "@/backend/config/types";

  export let hidden: boolean;

  async function awaitMediaPromise(mediaPromise: Promise<Media>) {
    // Clear previous media to show the skeleton as we await the new media
    media = undefined;
    mediaProgress = undefined;
    media = await mediaPromise;
    mediaProgress = getMediaProgress(media.id);
  }

  let media: Media | undefined;
  let mediaProgress: MediaProgress | undefined;

  $: $previewMedia && awaitMediaPromise($previewMedia);
</script>

{#if $previewResult}
  <PageWrapper {hidden}>
    {#if !media}
      <PreviewSkeleton isMovie={$previewResult.isMovie} />
    {:else}
      <div class="flex max-h-screen">
        <div class="overflow-y-auto {media.canHaveEpisodes ? 'w-2/3' : ''} p-2">
          <TopInfo {media} {mediaProgress} />
          <BottomInfo {media} />
        </div>
        {#if media.canHaveEpisodes}
          <SeasonsContainer {media} {mediaProgress} />
        {/if}
      </div>
    {/if}
  </PageWrapper>
{/if}
