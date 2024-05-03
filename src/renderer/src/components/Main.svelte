<script lang="ts">
  import Search from "./search/Main.svelte";
  import Preview from "./preview/Main.svelte";
  import { Page } from "./common/types";
  import { currentPage } from "./common/store";
</script>

{#if $currentPage === Page.Search}
  <Search />
{:else if $currentPage == Page.Preview}
  <Preview />
{/if}
