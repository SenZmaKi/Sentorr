<script lang="ts">
  import type { BaseResult } from "$backend/imdb/types";

  import ImagePlaceholder from "./ImagePlaceholder.svelte";
  export let result: BaseResult;
  function secondsToHm(seconds: number): string {
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) {
      return `${minutes}m`;
    }
    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;
    if (remainingMinutes === 0) return `${hours}h`;
    if (hours === 0) return `${remainingMinutes}m`;
    return `${hours}h ${remainingMinutes}m`;
  }

  function ratingToColor(rating: number): string {
    let hue = rating * 12;
    return `hsl(${hue}, 100%, 50%)`;
  }

  function ratingToPercentage(rating: number): string {
    return `${rating * 10}%`;
  }
  let imageIsLoading = true;
</script>

<div
  class="xxs-dark  w-[550px] h-[280px] shadow-lg shadow-black  rounded-lg transform transition duration-300 ease-in-out hover:scale-105 cursor-pointer flex"
>
  {#if result.imageUrl}
    {#if imageIsLoading}
      <ImagePlaceholder width="200px" animate={true} />
    {/if}
    <img
      hidden={imageIsLoading}
      dir="ltr"
      class="pr-2 rounded-lg w-[200px] h-[280px]"
      src={result.imageUrl}
      alt="mediaPrimaryImage"
      on:load={() => (imageIsLoading = false)}
    />
  {:else}
    <ImagePlaceholder width="200px" animate={false} />
  {/if}
  <div class="p-2 h-[250px] justify-between flex flex-col">
    <!--TODO: Fix long titles-->
    <div>
      <div class="p-1 text-lg">
        {#if result.rating}
          <span
            class="font-extrabold"
            style="color: {ratingToColor(result.rating)}"
            >{ratingToPercentage(result.rating)}</span
          >
        {/if}
        {#if result.title}
          <span class="font-semibold">{result.title}</span>
        {/if}
      </div>
      <div class="text-sm">
        <div class="flex text-gray-300 pt-1 font-semibold">
          {#if result.type}
            <span>{result.type}</span>
            {#if result.releaseYear || result.runtime}
              <span>&nbsp•&nbsp</span>
            {/if}
          {/if}
          {#if result.releaseYear}
            <span>{result.releaseYear}</span>
            {#if result.runtime}
              <span>&nbsp•&nbsp</span>
            {/if}
          {/if}
          {#if result.runtime}
            <span>{secondsToHm(result.runtime)}</span>
          {/if}
        </div>
        {#if result.plot}
          <div class="pt-4 text-gray-200 h-36 overflow-y-auto">
            {result.plot}
          </div>
        {/if}
      </div>
    </div>
    <div class="font-semibold pt-3">
      {#if result.genres}
        {#each result.genres as genre, idx}
          <span>{genre}{result.genres.length - 1 == idx ? "" : " •"}&nbsp</span>
        {/each}
      {/if}
    </div>
  </div>
</div>
