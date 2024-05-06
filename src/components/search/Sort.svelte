<script lang="ts">
  import { SortOrder, SortBy } from "$backend/imdb/types";
  import { sortBy, sortOrder } from "./store";
  const formattedSortBy = {
    [SortBy.POPULARITY]: "Popularity rank",
    [SortBy.USER_RATING]: "Rating",
    [SortBy.BOX_OFFICE_GROSS_DOMESTIC]: "Box office",
    [SortBy.TITLE_REGIONAL]: "Title",
    [SortBy.RUNTIME]: "Runtime",
    [SortBy.RELEASE_DATE]: "Release date",
    [SortBy.YEAR]: "Release year",
    [SortBy.USER_RATING_COUNT]: "Rating count",
  } as const;

  $: updateSortOrder($sortBy);

  function updateSortOrder(newSortBy: SortBy | undefined) {
    if (newSortBy && [SortBy.POPULARITY, SortBy.RUNTIME].includes(newSortBy)) {
      $sortOrder = SortOrder.ASC;
    } else {
      $sortOrder = SortOrder.DESC;
    }
  }

  $: rotation = $sortOrder === SortOrder.ASC ? "rotate-180" : "";
</script>

<div class="flex items-center gap-5 pr-3">
  <div>
    <span>Sort by</span>
    <select bind:value={$sortBy}>
      {#each Object.entries(formattedSortBy) as [key, value]}
        <option value={key}>{value}</option>
      {/each}
    </select>
  </div>
  <button
    class="hover:scale-125"
    on:click={() => {
      $sortOrder =
        $sortOrder === SortOrder.ASC ? SortOrder.DESC : SortOrder.ASC;
    }}
  >
    <svg
      fill="white"
      class={rotation}
      width="15px"
      height="15px"
      viewBox="0 0 16 16"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M13 12.208V7h-2v5.137l-1.086-1.086L8.5 12.466 12.036 16l3.535-3.535-1.414-1.415L13 12.208zM8 6H0v2h8V6zm6-3H0v2h14V3zm2-3H0v2h16V0zM6 9H0v2h6V9zm-2 3H0v2h4v-2z"
        fill-rule="evenodd"
      />
    </svg>
  </button>
</div>
