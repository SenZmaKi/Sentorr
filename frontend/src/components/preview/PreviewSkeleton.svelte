<script lang="ts">
  import TopInfoSkeleton from "./TopInfoSkeleton.svelte";
  import BottomInfoSkeleton from "./BottomInfoSkeleton.svelte";
  import PageWrapper from "../common/PageWrapper.svelte";
  import { switchToSearchPage } from "../common/functions";
</script>

<PageWrapper>
  <div class="">
    <div class="overflow-y-auto absolute w-2/3 h-full p-2 animate-pulse">
      <button on:click={switchToSearchPage}>Search</button>
      <TopInfoSkeleton />
      <BottomInfoSkeleton />
    </div>
  </div>
</PageWrapper>
