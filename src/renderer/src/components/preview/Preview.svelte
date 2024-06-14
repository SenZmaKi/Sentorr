<script lang="ts">
  import { type Media } from "$backend/imdb/types";
  import TopInfo from "./TopInfo.svelte";
  import BottomInfo from "./BottomInfo.svelte";
  import { switchToSearchPage } from "../common/functions";
  import PageWrapper from "../common/PageWrapper.svelte";
  import SeasonsContainer from "./SeasonsContainer.svelte";

  export let media: Media;
</script>

<PageWrapper>
  <div class="flex">
    <div class="overflow-y-auto w-2/3 h-full p-2">
      <!-- TODO: Make this prettier -->
      <button on:click={switchToSearchPage}>Search</button>
      <TopInfo {media} />
      <BottomInfo {media} />
    </div>
    <SeasonsContainer {media}/>
  </div>
</PageWrapper>
