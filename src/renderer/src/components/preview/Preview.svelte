<script lang="ts">
  import TopInfo from "./TopInfo.svelte";
  import BottomInfo from "./BottomInfo.svelte";
  import SeasonsContainer from "./SeasonsContainer.svelte";
  import {
    currentPage,
    getMediaProgress,
    previewMedia,
    previewResult,
  } from "../common/store";
  import PreviewSkeleton from "./PreviewSkeleton.svelte";
  import PageWrapper from "../common/PageWrapper.svelte";
  import type { Media } from "@/backend/imdb/types";
  import type { MediaProgress } from "@/backend/config/types";
  import { Page } from "../common/types";

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
  <PageWrapper hidden={$currentPage !== Page.Preview}>
    {#if !media}
      <PreviewSkeleton canHaveEpisodes={$previewResult.canHaveEpisodes} />
    {:else}
      <div class="flex max-h-screen">
        <div
          class="overflow-y-auto {media.canHaveEpisodes ? 'w-[60%]' : ''} p-2"
        >
          <TopInfo {media} {mediaProgress} />
          <BottomInfo {media} />
        </div>
        {#if media.canHaveEpisodes}
          <div class="w-[40%]">
            <SeasonsContainer {media} {mediaProgress} />
          </div>
        {/if}
      </div>
    {/if}
  </PageWrapper>
{/if}
