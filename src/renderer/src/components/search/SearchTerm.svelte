<script lang="ts">
  import FilterWrapper from "./FilterWrapper.svelte";
  import { searchTerm } from "./store";
  let value = "";
  $: {
    if (value == "") $searchTerm = undefined;
    else $searchTerm = value;
  }
</script>

<FilterWrapper name="Title" viewBox="0 0 24 24">
  <path
    slot="svgpath"
    d="M15.7955 15.8111L21 21M18 10.5C18 14.6421 14.6421 18 10.5 18C6.35786 18 3 14.6421 3 10.5C3 6.35786 6.35786 3 10.5 3C14.6421 3 18 6.35786 18 10.5Z"
    fill="#141414"
    stroke="white"
    stroke-width="2"
    stroke-linecap="round"
    stroke-linejoin="round"
  />
  <input slot="picker" bind:value type="text" placeholder="Any" />
</FilterWrapper>
