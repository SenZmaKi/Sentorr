<script lang="ts">
  import TopInfoSkeleton from "./TopInfoSkeleton.svelte";
  import BottomInfoSkeleton from "./BottomInfoSkeleton.svelte";
  import PageWrapper from "../common/PageWrapper.svelte";
  import { switchToSearchPage } from "../common/functions";
  import SeasonsContainerSkeleton from "./SeasonsContainerSkeleton.svelte";
</script>

<PageWrapper>
  <div class="flex max-h-screen">
    <div class="overflow-y-auto w-2/3 animate-pulse">
      <button on:click={switchToSearchPage}>Search</button>
      <TopInfoSkeleton />
      <BottomInfoSkeleton />
    </div>
    <SeasonsContainerSkeleton />
    </div>
</PageWrapper>
