<script lang="ts">
  import MediaType from "./MediaType.svelte";
  import Genre from "./Genre.svelte";
  import SearchTerm from "./SearchTerm.svelte";
  import Runtime from "./Runtime.svelte";
  import Rating from "./Rating.svelte";
  import Year from "./Year.svelte";
  import AllSelectedVariants from "./AllSelectedVariants.svelte";
  import Sort from "./Sort.svelte";
  import ResultsContainer from "./ResultsContainer.svelte";
  import PageWrapper from "../common/PageWrapper.svelte";
  import MediaCardTypes from "./MediaCardTypes.svelte";
  import { Page } from "../common/types";
</script>

<PageWrapper page={Page.Search}>
  <div class="opacity-90 flex-col justify-between p-3">
    <div class="flex justify-between flex-wrap m-4 gap-4">
      <SearchTerm />
      <Genre />
      <MediaType />
      <Rating />
      <Year />
      <Runtime />
    </div>
    <div class="flex flex-wrap items-baseline pt-3 pb-3 justify-between">
      <AllSelectedVariants />
      <div class="flex flex-wrap pt-2">
        <MediaCardTypes />
        <Sort />
      </div>
    </div>
    <ResultsContainer />
  </div>
</PageWrapper>
