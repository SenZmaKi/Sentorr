<script lang="ts">
  import type { Page } from "../common/types";
  import { currentPage } from "../common/store";

  export let page: Page;
  export let viewBox: string;
</script>

<div class="p-2 pb-4">
  <button
    class="p-[1px] rounded hover:scale-150 ease-in-out duration-500 cursor-pointer "
    on:click={() => ($currentPage = page)}
    class:bg-white={$currentPage === page}
  >
    <svg
      class="w-6 h-6"
      class:fill-black={$currentPage === page}
      {viewBox}
      xmlns="http://www.w3.org/2000/svg"
    >
      <slot />
    </svg>
  </button>
</div>

<style>
</style>
