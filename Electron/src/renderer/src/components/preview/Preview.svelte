<script lang="ts">
  import TopInfo from "./TopInfo.svelte";
  import BottomInfo from "./BottomInfo.svelte";
  import SeasonsContainer from "./SeasonsContainer.svelte";
  import {
    getMediaProgress,
    previewMediaPromise,
    previewResult,
  } from "../common/store";
  import PreviewSkeleton from "./PreviewSkeleton.svelte";
  import PageWrapper from "../common/PageWrapper.svelte";
  import type { Media } from "@/backend/imdb/types";
  import type { MediaProgress } from "@/backend/config/types";
  import { Page } from "../common/types";
  import PageTransition from "../common/PageTransition.svelte";

  async function awaitMediaPromise(mediaPromise: Promise<Media>) {
    // Clear previous media to show the skeleton as we await the new media
    media = undefined;
    mediaProgress = undefined;
    media = await mediaPromise;
    mediaProgress = getMediaProgress(media.id);
  }

  let media: Media | undefined = undefined;
  let mediaProgress: MediaProgress | undefined = undefined;

  $: if ($previewMediaPromise) awaitMediaPromise($previewMediaPromise);
</script>

<PageWrapper page={Page.Preview}>
  {#if $previewResult}
    <div class="relative">
      {#key $previewMediaPromise}
        <PageTransition class="flex">
          {#if !media}
            <PreviewSkeleton canHaveEpisodes={$previewResult.canHaveEpisodes} />
          {:else}
            <div
              class="overflow-y-auto h-screen {media.canHaveEpisodes
                ? 'w-[60%]'
                : ''} p-2"
            >
              <TopInfo {media} {mediaProgress} />
              <BottomInfo {media} />
            </div>
            {#if media.canHaveEpisodes}
              <div class="w-[40%]">
                <SeasonsContainer {media} {mediaProgress} />
              </div>
            {/if}
          {/if}
        </PageTransition>
      {/key}
    </div>
  {/if}
</PageWrapper>
