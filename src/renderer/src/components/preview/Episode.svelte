<script lang="ts">
  import type { ImdbDate, Episode, Media } from "@/backend/imdb/types";
  import ImageSkeleton from "../common/ImageSkeleton.svelte";
  import Rating from "../common/Rating.svelte";
  import { switchToPlayerPage } from "../common/functions";
  import type { MediaProgress } from "@/backend/config/types";

  export let episode: Episode;
  export let media: Media;
  export let mediaProgress: MediaProgress | undefined = undefined;

  function prettyDate({
    day,
    month,
    year,
  }: ImdbDate): [string | undefined, boolean] {
    if (!day || !month || !year) return [undefined, false];
    const dateObj = new Date(`${year}-${month}-${day}`);
    const currentDate = new Date();
    const diffTime = Math.abs(currentDate.getTime() - dateObj.getTime());
    const msToDays = 1000 * 60 * 60 * 24;
    const diffDays = Math.ceil(diffTime / msToDays);
    const diffWeeks = Math.floor(diffDays / 7);

    if (
      dateObj.getFullYear() === currentDate.getFullYear() &&
      dateObj.getMonth() === currentDate.getMonth()
    ) {
      if (dateObj.getDate() === currentDate.getDate()) return ["Today", true];
      else if (dateObj.getDate() === currentDate.getDate() + 1)
        return ["Tomorrow", false];
      else if (dateObj.getDate() === currentDate.getDate() - 1)
        return ["Yesterday", true];
    }

    if (dateObj > currentDate) {
      // Future dates
      if (diffDays < 7) return [`In ${diffDays} days`, false];
      if (diffDays < 30)
        return [`In ${diffWeeks} week${diffWeeks > 1 ? "s" : ""}`, false];
      if (diffDays < 365) {
        const diffMonths = Math.floor(diffDays / 30);
        return diffMonths > 1
          ? [`In ${diffMonths} month${diffMonths > 1 ? "s" : ""}`, false]
          : ["In 1 month", false];
      }
      const diffYears = Math.floor(diffDays / 365);
      return [`In ${diffYears} year${diffYears > 1 ? "s" : ""}`, false];
    }

    // Past dates
    if (diffDays < 7) return [`${diffDays} days ago`, true];
    if (diffDays < 30)
      return [`${diffWeeks} week${diffWeeks > 1 ? "s" : ""} ago`, true];
    if (diffDays < 365) {
      const diffMonths = Math.floor(diffDays / 30);
      return [`${diffMonths} month${diffMonths > 1 ? "s" : ""} ago`, true];
    }
    const diffYears = Math.floor(diffDays / 365);
    return [`${diffYears} year${diffYears > 1 ? "s" : ""} ago`, true];
  }

  const [prettyReleaseDate] = episode.releaseDate
    ? prettyDate(episode.releaseDate)
    : [undefined, false];

  let button: HTMLButtonElement | undefined = undefined;
  const inProgress = mediaProgress?.episode?.id === episode.id;
  $: if (inProgress && button) button.focus();
</script>

<button
  bind:this={button}
  class="rounded shadow-xl shadow-black text-left flex xs-dark m-7 w-[90%] min-w-[350px] duration-300 cursor-pointer ease-in-out hover:scale-110 {inProgress
    ? // Add 4 extra pixels (2 to the top and 2 to the bottom) to the height
      // to account for the border otherwise the image will cut off the border
      'border-2 border-white'
    : ''}"
  on:click={() => {
    switchToPlayerPage(media, episode);
  }}
>
  {#if episode.imageUrl}
    <div>
      <ImageSkeleton
        imageUrl={episode.imageUrl}
        height={140}
        width={// width/height ratio on the site is 1.77774147882 but it looks janks sometimes
        220}
        rounded={true}
      />
    </div>
  {/if}
  <div class="p-2 flex flex-col justify-between">
    <div class="flex flex-col">
      <div class="flex items-baseline overflow-y-auto h-[30px]">
        {#if episode.rating}
          <div class="pr-2 text-sm">
            <Rating rating={episode.rating} />
          </div>
        {/if}
        <div class="">
          <span class="font-semibold text-sm"
            >{episode.seasonEpisode.episodeNumber}. {episode.title
              ? `${episode.title}`
              : ""}</span
          >
        </div>
      </div>
      {#if episode.plot}
        <div class="text-xs overflow-y-auto mb-2 max-h-[50px] opacity-85">
          {episode.plot}
        </div>
      {/if}
      {#if prettyReleaseDate}
        <div class="text-xs opacity-80">{prettyReleaseDate}</div>
      {/if}
    </div>
  </div>
</button>
