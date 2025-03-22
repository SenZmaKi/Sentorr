<script lang="ts">
  export let name: string;
  let showX = false;
  export let selectedVariants: string[] | undefined;
</script>

<button
  class="xxs-dark flex p-2 m-1 items-center text-sm rounded-md"
  on:mouseenter={() => (showX = true)}
  on:mouseleave={() => (showX = false)}
  on:click={() => {
    if (selectedVariants === undefined) {
      return;
    }
    selectedVariants = selectedVariants.filter((v) => v !== name);
    if (selectedVariants.length === 0) {
      selectedVariants = undefined;
    }
  }}
>
  {name}
  {#if showX}
    <span class="text-red-600 ml-1">x</span>
  {/if}
</button>
