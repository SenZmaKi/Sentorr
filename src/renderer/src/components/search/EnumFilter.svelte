<script lang="ts">
  import FilterWrapper from "./FilterWrapper.svelte";

  export let name: string;
  export let viewBox: string;
  export let variants: string[];
  export let selectedVariants: string[] | undefined;
  export let currentVariant: string | undefined;

  function setSelectedVariants(newVariant: string | undefined) {
    if (!newVariant) {
      selectedVariants = undefined;
      return;
    }

    if (!selectedVariants) {
      selectedVariants = [newVariant];
      return;
    }

    if (selectedVariants.includes(newVariant)) return;

    selectedVariants = [...selectedVariants, newVariant];
  }

  $: setSelectedVariants(currentVariant);
</script>

<FilterWrapper {viewBox} {name}>
  <slot slot="svgpath" />
  <select class="search-filter-input" slot="picker" bind:value={currentVariant}>
    <option value={undefined}>Any</option>
    {#each variants as v}
      <option value={v}>{v}</option>
    {/each}
  </select>
</FilterWrapper>
