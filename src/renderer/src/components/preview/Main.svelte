<!-- This wrapper component is to ensure the whole Preview component gets rerendered when previewMedia changes -->

<script lang="ts">
  import { previewMedia } from "../common/store";
  import Preview from "./Preview.svelte";
  // import media from "@/test-results/getMedia.json";
</script>

{#key $previewMedia}
  {#if $previewMedia}
    <Preview media={$previewMedia} />
  {/if}
{/key}

<!-- <Preview {media}/> -->
