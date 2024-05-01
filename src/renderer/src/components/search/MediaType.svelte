<script lang="ts">
  import {
    formattedMediaTypes,
    formattedMediaTypesMap,
  } from "../common/constants";
  import EnumFilter from "./EnumFilter.svelte";
  import FilterIcon from "./FilterIcon.svelte";
  import { selectedFormattedMediaTypes, mediaTypes } from "./store.js";

  $: {
    if ($selectedFormattedMediaTypes !== undefined) {
      $mediaTypes = $selectedFormattedMediaTypes.map(
        (key) => formattedMediaTypesMap[key],
      );
    } else {
      $mediaTypes = undefined;
    }
  }
</script>

<EnumFilter
  bind:selectedVariants={$selectedFormattedMediaTypes}
  variants={formattedMediaTypes}
  name="Type"
>
  <FilterIcon viewBox="0 0 50 50">
    <g>
      <path d="M1,38h23v3H12v2h26v-2H26v-3h23V8H1V38z M3,10h44v26H3V10z" />
    </g>
  </FilterIcon>
</EnumFilter>
