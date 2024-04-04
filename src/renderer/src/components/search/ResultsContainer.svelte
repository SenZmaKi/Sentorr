<script lang="ts">
  import { search } from "$backend/imdb/api";
  // import results from "$frontend/test/data/search.json";
  import type { BaseResult } from "$backend/imdb/types";
  import MediaCard from "./common/mediacard/Complex.svelte";
  import ComplexPlaceholder from "./common/mediacard/ComplexPlaceholder.svelte";
  import { searchFilters } from "./store";

  $: pagination = search($searchFilters);
  let accumulatedResults: (BaseResult | undefined)[];
  $: console.log(accumulatedResults.length);
  $: {
    $searchFilters;
    accumulatedResults = [];
  }
  let resultsDiv: HTMLElement;
  $: {
    $searchFilters;
    if (resultsDiv) resultsDiv.scrollTo(0, 0);
  }
  $: pagination, updateAccumulatedResults();
  async function updateAccumulatedResults() {
    accumulatedResults = [
      ...accumulatedResults,
      ...Array.from({ length: 25 }, (_) => undefined),
    ];
    const results = (await pagination).results;
    accumulatedResults = accumulatedResults.slice(undefined, -25);
    accumulatedResults = [...accumulatedResults, ...results];
  }

  async function infiniteScroll(event: Event | null) {
    if (!event) return;
    const element = event.target as HTMLElement;
    // when the user is 30% away from the bottom of the page or rather scrolled 70% of the page
    const nearingBottom =
      (element.clientHeight + element.scrollTop) / element.scrollHeight >= 0.7;
    if (nearingBottom) {
      const awaitedPagination = await pagination;
      if (awaitedPagination.next) {
        pagination = awaitedPagination.next();
      }
    }
  }
</script>

{#if accumulatedResults.length}
  <div
    bind:this={resultsDiv}
    on:scroll={infiniteScroll}
    class="grid gap-x-10 gap-y-5 overflow-y-auto max-h-[82vh]"
    style="grid-template-columns: repeat(auto-fill, minmax(550px, 1fr));"
  >
    {#each accumulatedResults as result}
      {#if result}
        <MediaCard {result} />
      {:else}
        <ComplexPlaceholder />
      {/if}
    {/each}
    <div class="pt-6"></div>
  </div>
{:else}
  <div class="pt-28 justify-center items-center flex-col flex">
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="h-40 w-40"
      viewBox="0 0 24 24"
      fill="currentColor"
      role="presentation"
      data-darkreader-inline-fill=""
      ><g fill="none"
        ><path d="M0 0h24v24H0z"></path><path d="M0 0h24v24H0z"></path></g
      ><path
        d="M15.5 14h-.79l-.28-.27a6.5 6.5 0 001.48-5.34c-.47-2.78-2.79-4.99-5.58-5.34A6.492 6.492 0 003.03 9h2.02c.24-2.12 1.92-3.8 4.06-3.98C11.65 4.8 14 6.95 14 9.5c0 2.49-2.01 4.5-4.5 4.5-.17 0-.33-.03-.5-.05v2.02l.01.01c1.8.13 3.47-.47 4.72-1.55l.27.28v.79l4.25 4.25c.41.41 1.08.41 1.49 0 .41-.41.41-1.08 0-1.49L15.5 14z"
      ></path><path
        d="M6.12 11.17L4 13.29l-2.12-2.12c-.2-.2-.51-.2-.71 0-.2.2-.2.51 0 .71L3.29 14l-2.12 2.12c-.2.2-.2.51 0 .71.2.2.51.2.71 0L4 14.71l2.12 2.12c.2.2.51.2.71 0 .2-.2.2-.51 0-.71L4.71 14l2.12-2.12c.2-.2.2-.51 0-.71a.513.513 0 00-.71 0z"
      ></path></svg
    >
    <div class="font-bold text-2xl">No results found</div>
  </div>
{/if}
