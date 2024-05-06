<!-- This wrapper component is to ensure the whole Preview component gets rerendered when previewMedia changes -->

<script lang="ts">
  import { previewMedia } from "../common/store";
  import Preview from "./Preview.svelte";
  import PreviewSkeleton from "./PreviewSkeleton.svelte";
  // import media from "@/test-results/getMedia.json";
</script>

{#await $previewMedia}
  <PreviewSkeleton />
{:then media}
  {#key media}
    {#if media}
      <Preview {media} />
    {/if}
  {/key}
{/await}
