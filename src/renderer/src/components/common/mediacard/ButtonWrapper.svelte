<script lang="ts">
  import {
    switchToPreviewPage,
  } from "../functions";
  import { getMedia } from "$backend/imdb/api";
  export let mediaID: string;
  export let class_: string;
</script>

<button
  style="text-align: unset;"
  class={class_}
  on:click={() => {
    switchToPreviewPage(getMedia(mediaID));
  }}
>
  <slot />
</button>
