<script lang="ts">
  import SelectedVariant from "./SelectedVariant.svelte";
  export let selectedVariants: string[] | undefined;
  export let currentVariant: string | undefined;
</script>

<div class="flex">
  {#if !!selectedVariants}
    {#each selectedVariants as sv}
      <SelectedVariant name={sv} bind:selectedVariants bind:currentVariant />
    {/each}
  {/if}
</div>
