<script lang="ts">
  import { getMedia } from "@/backend/imdb/api";
  import type { BaseResult } from "@/backend/imdb/types";
  import { switchToPreviewPage } from "../functions";
  let className: string;
  export { className as class };
  export let result: BaseResult;
</script>

<button
  class={`text-left ${className}`}
  on:click={() => {
    const mediaPromise = getMedia(result.id);
    switchToPreviewPage(mediaPromise, result);
  }}
>
  <slot />
</button>
