<script lang="ts">
  import Search from "./search/Main.svelte";
  import Preview from "./preview/Main.svelte";
  import { Page } from "./common/types";
  import Player from "./player/Main.svelte";
  import Navbar from "./navbar/Main.svelte";
  import { currentPage } from "./common/store";
  import { Toaster } from "svelte-sonner";
</script>

<div class="flex items-center">
  <Navbar />
  <div class="flex-1 w-[90%] h-screen">
    <Toaster
      visibleToasts={6}
      position="top-right"
      theme="dark"
      richColors
      duration={10_000}
      closeButton
    />

    <Search hidden={$currentPage !== Page.Search} />
    <Preview hidden={$currentPage !== Page.Preview} />
    <Player hidden={$currentPage !== Page.Player} />
  </div>
</div>
