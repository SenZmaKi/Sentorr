<script lang="ts">
    import type { Episode } from "$backend/imdb/types";
    import ImageSkeleton from "../common/ImageSkeleton.svelte";
    import Rating from "../common/Rating.svelte";
    export let episode: Episode;
    function prettyDate(date: string) {
        const [day, month, year] = date.split("-");
        const dateObj = new Date(`${year}-${month}-${day}`);
        const currentDate = new Date();
        
        const diffTime = Math.abs(currentDate.getTime() - dateObj.getTime());
        if (dateObj.getFullYear() === currentDate.getFullYear() &&
            dateObj.getMonth() === currentDate.getMonth() &&
            dateObj.getDate() === currentDate.getDate()) {
            return "Today";
        }
                                            // Milliseconds divisor
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)); 
        if (diffDays < 2)  return "Yesterday";
        if (diffDays < 30) return `${diffDays} days ago`;
        if (diffDays < 365) {
            const diffMonths = Math.floor(diffDays / 30);
            return diffMonths > 1 ? `${diffMonths} months ago` : "A month ago";
        }
        const diffYears = Math.floor(diffDays / 365);
        return diffYears > 1 ? `${diffYears} years ago` : "A year ago";
    }
</script>

<button 
  style="text-align: unset;"
  class="flex xs-dark m-7 h-[100px] duration-300 ease-in-out hover:scale-110 "
>
  {#if episode.imageUrl}
    <div>
    <ImageSkeleton imageUrl={episode.imageUrl} height={100} width={160}/>
    </div>
  {/if}
  <div class="p-2">
    <div class="flex items-baseline">
    {#if episode.rating}
      <div class="pr-2 text-sm">
        <Rating rating={episode.rating}/>
      </div>
    {/if}
      <div class="justify-between">
      <span class="font-semibold text-sm">{episode.number}. {episode.title ? `${ episode.title }` : ""}</span>
      </div>
    </div>
    {#if episode.plot}
      <div class="text-xs overflow-y-auto max-h-[50px]">
          {episode.plot}
      </div>
    {/if}
      {#if episode.releaseDate}
        <span class="text-xs opacity-80">{prettyDate(episode.releaseDate)}</span>
      {/if}
  </div>
</button>
