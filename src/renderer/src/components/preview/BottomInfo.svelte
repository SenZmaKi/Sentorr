<script lang="ts">
  import type { Media } from "@/backend/imdb/types";
  import Simple from "../common/mediacard/Simple.svelte";
  import Review from "../common/Review.svelte";
  import { getReviews } from "@/backend/imdb/api";

  import { createInfiniteScrollStore } from "../common/functions";
  import ReviewSkeleton from "../common/ReviewSkeleton.svelte";

  export let media: Media;

  let [accumulatedReviews, infiniteScroll] = createInfiniteScrollStore(
    (nextPageKey: string | undefined) =>
      getReviews(media.id, true, nextPageKey),
    true,
    10,
  );
</script>

<div class="">
  {#if media.plot}
    <div
      class="mt-10 xs-dark shadow-md shadow-black rounded-lg p-4 max-h-40 overflow-auto w-2/3"
    >
      <span class="opacity-85">
        {media.plot}
      </span>
    </div>
  {/if}
  <div class="flex mt-6">
    {#if media.creators && media.creators.length}
      <div class=" xs-dark rounded-lg mr-4 p-2 shadow-md shadow-black">
        <div class="opacity-85">
          <span class="font-extrabold">Creators:</span>
          {#each media.creators as creator, idx}
            <span
              >{creator}{media.creators.length - 1 == idx
                ? ""
                : " •"}&nbsp</span
            >
          {/each}
        </div>
      </div>
    {/if}
    {#if media.actors && media.actors.length}
      <div class="xs-dark rounded-lg p-2 shadow-md shadow-black">
        <div class="opacity-85">
          <span class="font-extrabold">Cast:</span>
          {#each media.actors.slice(0, 4) as actor, idx}
            <span
              >{actor.name}{media.actors.slice(0, 4).length - 1 == idx
                ? ""
                : " •"}&nbsp</span
            >
          {/each}
        </div>
      </div>
    {/if}
  </div>
</div>
<div class="">
  {#if media.recommendations && media.recommendations.length}
    <div class="text-opacity-90 pt-6 flex flex-col">
      <span class="font-semibold text-center text-lg opacity-90"
        >More like this</span
      >
      <hr class="h-2 mt-2 mb-2 xs-dark border-none shadow-md shadow-black" />
      <div class="flex overflow-x-auto">
        {#each media.recommendations as recommendation}
          {#if recommendation.imageUrl && recommendation.title}
            <Simple result={recommendation} />
          {/if}
        {/each}
      </div>
    </div>
  {/if}
  {#if $accumulatedReviews.length}
    <div class="flex flex-col pt-6">
      <span class="font-semibold text-center text-lg opacity-90">Reviews</span>
      <hr class="h-2 mt-2 mb-2 xs-dark border-none shadow-md shadow-black" />
      <div on:scroll={infiniteScroll} class="flex overflow-x-auto">
        {#each $accumulatedReviews as review}
          {#if review}
            <Review {review} width={256} height={192} />
          {:else}
            <ReviewSkeleton width={256} height={192} />
          {/if}
        {/each}
      </div>
    </div>
  {/if}
</div>
