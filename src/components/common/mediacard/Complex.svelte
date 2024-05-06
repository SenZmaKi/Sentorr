<script lang="ts">
  import type { BaseResult } from "$backend/imdb/types";
  import ImageSkeleton from "../ImageSkeleton.svelte";
  import Rating from "../Rating.svelte";
  import { secondsToHm } from "../functions";
  import ButtonWrapper from "./ButtonWrapper.svelte";

  export let result: BaseResult;
</script>

<ButtonWrapper
  class_="m-2 xxs-dark w-[480px] h-[240px] shadow-lg shadow-black rounded-lg duration-300 ease-in-out hover:scale-110 cursor-pointer flex"
  mediaID={result.id}
>
  <div class="w-[160px]">
    <ImageSkeleton url={result.imageUrl} width={160} height={240} />
  </div>
  <div class="p-2 opacity-90 justify-between flex flex-col">
    <div>
    <!--64px is the max limit below which a title with more than 1 line overflows-->
      <div class="p-1 text-lg overflow-y-auto max-h-[65px]">
        {#if result.rating}
          <Rating rating={result.rating} />
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
          <div class="pt-4  text-gray-200 h-[100px] overflow-y-auto">
            {result.plot}
          </div>
        {/if}
      </div>
    </div>
    <div class="font-semibold pt-2">
      {#if result.genres}
        {#each result.genres as genre, idx}
          <span>{genre}{result.genres.length - 1 == idx ? "" : " •"}&nbsp</span>
        {/each}
      {/if}
    </div>
  </div>
</ButtonWrapper>
