<script lang="ts">
  import Search from "./search/Main.svelte";
  import Preview from "./preview/Main.svelte";
  import { Page } from "./common/types";
  import { currentPage } from "./common/store";
</script>

<Search hidden={$currentPage !== Page.Search} />
<Preview hidden={$currentPage !== Page.Preview} />
