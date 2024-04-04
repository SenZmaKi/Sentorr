<script lang="ts">
  import SelectedVariant from "./SelectedVariant.svelte";
  export let selectedVariants: string[] | undefined;
</script>

<div class="flex">
  {#if selectedVariants !== undefined}
    {#each selectedVariants as sv}
      <SelectedVariant name={sv} bind:selectedVariants/>
    {/each}
  {/if}
</div>

