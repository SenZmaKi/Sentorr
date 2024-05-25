<script lang="ts">
  import { search } from "$backend/server/api";
  // import results from "@/test-results/search.json";
  import Complex from "../common/mediacard/Complex.svelte";
  import Simple from "../common/mediacard/Simple.svelte";
  import ComplexSkeleton from "../common/mediacard/ComplexSkeleton.svelte";
  import SimpleSkeleton from "../common/mediacard/SimpleSkeleton.svelte";
  import { searchFilters } from "./store";
  import { createInfiniteScrollStore } from "../common/functions";
  import type { Writable } from "svelte/store";
  import type { BaseResult } from "$backend/imdb/types";
  import { mediaCardType } from "../common/store";
  import {MediaCardType} from "../common/types";

  let accumulatedResults: Writable<(BaseResult | undefined)[]>;
  let infiniteScroll: (event: Event | null) => void;
  $: {
    [accumulatedResults, infiniteScroll] = createInfiniteScrollStore(
      search($searchFilters),
      false,
      25,
    );
  }
  let resultsDiv: HTMLDivElement;
  $: {
    $searchFilters;
    if (resultsDiv) resultsDiv.scrollTo(0, 0);
  }
</script>

{#if $accumulatedResults.length}
  <div
    bind:this={resultsDiv}
    on:scroll={infiniteScroll}
    class="max-h-[82vh] flex-wrap justify-center items-center flex overflow-y-auto"
  >
    {#each $accumulatedResults as result}
      <div class="m-4">
        {#if result}
          {#if $mediaCardType == MediaCardType.Simple}
            <Simple {result} />
          {:else}
            <Complex {result} />
          {/if}
        {:else if $mediaCardType == MediaCardType.Simple}
          <SimpleSkeleton />
        {:else}
          <ComplexSkeleton />
        {/if}
      </div>
    {/each}
    <div class="h-[50px] w-full"></div>
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
