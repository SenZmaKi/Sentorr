<script lang="ts">
  import type { BaseResult } from "$backend/imdb/types";
  import ImageSkeleton from "../ImageSkeleton.svelte";
  import Rating from "../Rating.svelte";
  import { secondsToHm } from "../functions";
  import ButtonWrapper from "./ButtonWrapper.svelte";

  export let result: BaseResult;
</script>

<ButtonWrapper
  class_=" m-4 xxs-dark w-[550px] h-[280px] shadow-lg shadow-black rounded-lg duration-300 ease-in-out hover:scale-105 cursor-pointer flex"
  mediaID={result.id}
>
  <div class="w-[200px]">
    <ImageSkeleton url={result.imageUrl} width={200} height={280} />
  </div>
  <div class="p-2 opacity-90 h-[250px] justify-between flex flex-col">
    <!--TODO: Fix long titles-->
    <div>
      <div class="p-1 text-lg">
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
</ButtonWrapper>
