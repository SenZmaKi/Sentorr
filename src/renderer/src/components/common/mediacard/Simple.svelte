<script lang="ts">
  import ImageSkeleton from "../ImageSkeleton.svelte";
  import type { BaseResult } from "@/backend/imdb/types";
  import ButtonWrapper from "./ButtonWrapper.svelte";
  import Rating from "../Rating.svelte";
  export let result: BaseResult;
</script>

<ButtonWrapper
  class="w-[144px] m-4 xs-dark shadow-black shadow-lg rounded-lg p-1 flex items-center flex-col cursor-pointer ease-in-out hover:scale-110 duration-300"
  {result}
>
  <ImageSkeleton imageUrl={result.imageUrl} width={130} height={180} />
  <div class="text-center p-2 font-semibold text-sm opacity-90">
    {#if result.rating}
      <div>
        <Rating rating={result.rating} />
      </div>
    {/if}
    {result.title}
  </div>
</ButtonWrapper>
