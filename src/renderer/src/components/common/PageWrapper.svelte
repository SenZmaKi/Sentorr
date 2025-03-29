<script lang="ts">
  import { currentPage } from "./store";
  import type { Page } from "./types";
  import PageTransition from "./PageTransition.svelte";

  export let page: Page;
</script>

{#if $currentPage === page}
  <PageTransition>
    <slot />
  </PageTransition>
{/if}
