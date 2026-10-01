<script lang="ts">
  import { tippy } from "../common/constants";
  import FilterWrapper from "./FilterWrapper.svelte";
  import { type Range } from "@/backend/imdb/types";

  export let range: Range | undefined = undefined;
  export let name: string;
  export let viewBox: string;
  export let minRange = 0;
  export let maxRange: number | undefined = undefined;
  export let tooltip: string | undefined = undefined;

  function validateMinAndMaxRange() {
    if (minInput !== null && maxInput !== null) {
      if (minInput > maxInput) {
        minInput = maxInput;
      }
    }
    if (maxRange !== undefined) {
      if (minInput !== null && minInput > maxRange) {
        minInput = maxRange;
      }
      if (maxInput !== null && maxInput > maxRange) {
        maxInput = maxRange;
      }
    }
    if (minInput !== null && minInput < minRange) minInput = minRange;
    if (maxInput !== null && maxInput < minRange) maxInput = minRange;
  }

  function updateRange() {
    if (minInput === null && maxInput === null) {
      range = undefined;
      // The !== null checks are redundant, but they are here to satisfy TypeScript
    } else if (minInput === null && maxInput !== null) {
      range = { max: maxInput };
    } else if (maxInput === null && minInput !== null) {
      range = { min: minInput };
    } else if (minInput !== null && maxInput !== null) {
      range = { min: minInput, max: maxInput };
    }
  }

  function onChange() {
    validateMinAndMaxRange();
    updateRange();
  }

  let minInput: number | null = null;
  let maxInput: number | null = null;

  $: maybeTippy = tooltip ? tippy : () => {};
</script>

<FilterWrapper {name} {viewBox}>
  <slot slot="svgpath" />
  <div slot="picker" class="flex">
    <input
      class="search-filter-input w-24"
      use:maybeTippy={{ content: tooltip, placement: "bottom" }}
      on:focusout={onChange}
      on:change={onChange}
      min={minRange}
      max={maxRange}
      type="number"
      placeholder="Any"
      bind:value={minInput}
    />
    <span class="pr-1 pl-1"> to </span>
    <input
      class="search-filter-input w-24"
      use:maybeTippy={{ content: tooltip, placement: "bottom" }}
      on:change={onChange}
      on:focusout={onChange}
      min={minRange}
      max={maxRange}
      type="number"
      placeholder="Any"
      bind:value={maxInput}
    />
  </div>
</FilterWrapper>
