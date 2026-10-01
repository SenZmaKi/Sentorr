<script lang="ts">
  import { slide } from "svelte/transition";

  export let name: string;
  export let selectedVariants: string[] | undefined;
  export let currentVariant: string | undefined;

  let showX = false;
</script>

<button
  in:slide={{ duration: 300 }}
  class="xxs-dark flex p-2 items-center text-sm rounded-md hover:scale-110 ease-in-out duration-300"
  on:mouseenter={() => (showX = true)}
  on:mouseleave={() => (showX = false)}
  on:click={() => {
    if (selectedVariants === undefined) return;

    selectedVariants = selectedVariants.filter((v) => v !== name);
    if (!selectedVariants.length) {
      currentVariant = undefined;
      return;
    }
    if (name === currentVariant)
      currentVariant = selectedVariants[selectedVariants.length - 1];
  }}
>
  {name}
  {#if showX}
    <span class="text-red-600 ml-1">x</span>
  {/if}
</button>
