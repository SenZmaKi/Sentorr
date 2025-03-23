<script lang="ts">
  import { getMedia } from "@/backend/imdb/api";
  import type { BaseResult } from "@/backend/imdb/types";
  import { switchToPreviewPage } from "../functions";
  export let class_: string;
  export let result: BaseResult;
</script>

<button
  class={`text-left ${class_}`}
  on:click={() => {
    const media = getMedia(result.id);
    switchToPreviewPage(media, result);
  }}
>
  <slot />
</button>
