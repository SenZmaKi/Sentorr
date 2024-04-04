<script lang="ts">
  import FilterHeader from "./FilterHeader.svelte";

  export let name: string;
  export let variants: string[];
  export let selectedVariants: string[] | undefined;
  let currentVariant: string | undefined = undefined;
  $: selectedVariants = getVariants(currentVariant);

  function getVariants(newVariant: string | undefined): string[] | undefined {
    if (newVariant === undefined) {
      return undefined;
    }
    if (selectedVariants === undefined) {
      return [newVariant];
    }
    if (selectedVariants.includes(newVariant)) {
      return selectedVariants;
    }
    return [...selectedVariants, newVariant];
  }
</script>

<div>
  <FilterHeader {name}>
    <slot />
  </FilterHeader>
  <select bind:value={currentVariant}>
    <option value={undefined}>Any</option>
    {#each variants as v}
      <option value={v}>{v}</option>
    {/each}
  </select>
</div>
