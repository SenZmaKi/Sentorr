<script lang="ts">
  import type { Review } from "@/backend/imdb/types";
  import Rating from "./Rating.svelte";
  import Like from "./Like.svelte";
  export let review: Review;
  export let width: number;
  export let height: number;
</script>

{#if !review.hasSpoilers}
  <div
    class="m-4 p-2 xs-dark shadow-lg shadow-black flex flex-col rounded-lg justify-between"
    style="min-width: {width}px; height: {height}px"
  >
    <div class="text-sm font-semibold overflow-y-auto max-h-[25%] opacity-90">
      {#if review.rating}
        <Rating rating={review.rating} />
      {/if}
      <span>{review.title}</span>
    </div>
    <div class="text-xs overflow-y-auto pt-1 h-[55%] opacity-80">
      {review.content}
    </div>
    <div class="flex mt-2 mb-2 opacity-90">
      <Like IsDislike={false} count={review.likes} />
      <Like IsDislike={true} count={review.dislikes} />
    </div>
    <div class="text-xs opacity-80">
      @{review.author}
      &nbsp;&nbsp;
      {review.date}
    </div>
  </div>
{/if}
