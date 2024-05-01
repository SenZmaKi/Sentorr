<script lang="ts">
  import { type Media, MediaType } from "$backend/imdb/types";
  import { formattedMediaTypesMap } from "../common/constants";
  import TopInfo from "./TopInfo.svelte";
  import BottomInfo from "./BottomInfo.svelte";
  import { switchToSearchPage } from "../common/functions";
  import PageWrapper from "../common/PageWrapper.svelte";
  export let media: Media;
  const mediaType = formattedMediaTypesMap[
    media?.type ?? MediaType.TVSeries
  ] as MediaType;
  const isMovie =
    mediaType === MediaType.TVMovie || mediaType === MediaType.Movie;
  let bannerIsLoading = true;
</script>

<PageWrapper>
  <div class="">
    {#if media.bannerImageUrl}
      <img
        hidden={bannerIsLoading}
        on:load={() => (bannerIsLoading = false)}
        class="absolute opacity-30 w-full h-full"
        src={media.bannerImageUrl}
        alt="mediaBannerImage"
      />
    {/if}
    <div class="overflow-y-auto absolute w-2/3 h-full p-2">
      <!-- TODO: Make this prettier -->
      <button on:click={switchToSearchPage}>Search</button>
      <TopInfo {media} {isMovie} />
      <BottomInfo {media} />
    </div>
  </div>
</PageWrapper>
