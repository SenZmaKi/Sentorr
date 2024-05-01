<script lang="ts">
  import {
    setLoadingTask,
    switchToPreviewPage,
    clearLoadingTask,
  } from "../functions";
  import { getMedia } from "$backend/imdb/api";
  export let mediaID: string;
  export let class_: string;
</script>

<button
  style="text-align: unset;"
  class={class_}
  on:click={() => {
    const task = async () => {
      const media = await getMedia(mediaID);
      switchToPreviewPage(media);
      clearLoadingTask();
    };
    setLoadingTask(task);
  }}
>
  <slot />
</button>
