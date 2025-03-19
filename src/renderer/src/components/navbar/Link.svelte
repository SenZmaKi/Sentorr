<script lang="ts">
  import type { Page } from "../common/types";
  import { currentPage } from "../common/store";
  import { scale } from "svelte/transition";

  export let page: Page;
  export let viewBox: string;
</script>

<div class="p-2 pb-4 flex justify-center items-center">
  <button
    class="relative p-2 rounded-full transition-transform duration-500 ease-in-out hover:scale-125 cursor-pointer
             bg-gray-800 hover:bg-gray-700
              shadow-md hover:shadow-lg active:shadow-sm"
    on:click={() => ($currentPage = page)}
  >
    <svg
      class="w-6 h-6 transition-colors duration-300"
      {viewBox}
      xmlns="http://www.w3.org/2000/svg"
    >
      <slot />
    </svg>
    {#if $currentPage === page}
      <span
        transition:scale
        class="absolute top-0 right-0 w-3 h-3 bg-blue-300 rounded-full border-2 border-white dark:border-gray-800"
      ></span>
    {/if}
  </button>
</div>
