<script lang="ts">
  import FilterWrapper from "./FilterWrapper.svelte";

  export let name: string;
  export let viewBox: string;
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

<FilterWrapper {viewBox} {name}>
  <slot slot="svgpath" />
  <select slot="picker" bind:value={currentVariant}>
    <option value={undefined}>Any</option>
    {#each variants as v}
      <option value={v}>{v}</option>
    {/each}
  </select>
</FilterWrapper>
