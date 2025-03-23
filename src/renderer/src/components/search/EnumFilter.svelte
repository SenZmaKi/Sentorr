<script lang="ts">
  import FilterWrapper from "./FilterWrapper.svelte";

  export let name: string;
  export let viewBox: string;
  export let variants: string[];
  export let selectedVariants: string[] | undefined;
  export let currentVariant: string | undefined;

  function getVariants(newVariant: string | undefined) {
    if (!newVariant) return undefined;

    if (!selectedVariants) return [newVariant];

    if (selectedVariants.includes(newVariant)) return selectedVariants;

    return [...selectedVariants, newVariant];
  }

  $: selectedVariants = getVariants(currentVariant);
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
