<script lang="ts">
  import { getMedia } from "$backend/imdb/api";
  import { switchToPreviewPage } from "../functions";
  export let mediaID: string;
  export let class_: string;
</script>

<button
  style="text-align: unset;"
  class={class_}
  on:click={() => {
    const media = getMedia(mediaID);
    switchToPreviewPage(media);
  }}
>
  <slot />
</button>
