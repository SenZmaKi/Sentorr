<script lang="ts">
  import { getCompressedImageUrl, makeActionWhenInViewport } from "./functions";
  export let url: string | undefined = undefined;
  export let width: number;
  export let height: number;
  export let rounded = true;
  export let animate = false;
  export let compress = true;
  let isLoading = true;
  let compressedUrl: string | undefined = undefined;

  // Lazy load the compressed url such that we only get it if
  // the component is in the viewport i.e., on screen
  const actionWhenInViewPort = compress
    ? makeActionWhenInViewport(() => {
        if (url && compress && !compressedUrl) {
          getCompressedImageUrl({ url, width, height }).then((newUrl) => {
            compressedUrl = newUrl;
          });
        }
      })
    : () => {};
</script>

<div
  class="relative"
  style="width: {width}px; height: {height}px;"
  use:actionWhenInViewPort
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
  {#if !compress || compressedUrl}
    <img
      on:load={() => (isLoading = false)}
      class="absolute"
      loading="lazy"
      class:rounded
      style="width: {width}px; height: {height}px;"
      src={compressedUrl ?? url}
      alt=""
    />
  {/if}
</div>
