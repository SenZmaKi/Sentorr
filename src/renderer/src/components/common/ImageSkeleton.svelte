<script lang="ts">
  import { type ScalableImageUrl } from "@/backend/imdb/types";
  import { makeScaledImageUrl } from "@/backend/imdb/api";

  export let imageUrl: ScalableImageUrl | undefined = undefined;
  export let width: number;
  export let height: number;
  export let rounded = true;
  export let animate = false;
  let className = "";
  export { className as class };

  const url = imageUrl && makeScaledImageUrl(width, height, imageUrl);
  let isLoading = true;
</script>

<div
  class={`relative ${className}`}
  style="width: {width}px; height: {height}px;"
>
  {#if isLoading}
    <div
      class="absolute flex items-center justify-center bg-gray-700 text-gray-600"
      style="width: {width}px; height: {height}px;"
      class:animate-pulse={animate || !!url}
      class:rounded
    >
      <svg
        style="width: {width / 4}px; height: {height / 4}px"
        aria-hidden="true"
        xmlns="http://www.w3.org/2000/svg"
        fill="currentColor"
        viewBox="0 0 20 18"
      >
        <path
          d="M18 0H2a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2Zm-5.5 4a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3Zm4.376 10.481A1 1 0 0 1 16 15H4a1 1 0 0 1-.895-1.447l3.5-7A1 1 0 0 1 7.468 6a.965.965 0 0 1 .9.5l2.775 4.757 1.546-1.887a1 1 0 0 1 1.618.1l2.541 4a1 1 0 0 1 .028 1.011Z"
        />
      </svg>
    </div>
  {/if}
  {#if url}
    <img
      on:load={() => (isLoading = false)}
      class="absolute"
      loading="lazy"
      class:rounded
      style="width: {width}px; height: {height}px;"
      src={url}
      alt=""
    />
  {/if}
</div>
