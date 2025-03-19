<script lang="ts">
  import Search from "./components/search/Main.svelte";
  import Preview from "./components/preview/Preview.svelte";
  import { Page } from "./components/common/types";
  import Player from "./components/player/Player.svelte";
  import Navbar from "./components/navbar/Navbar.svelte";
  import { currentPage } from "./components/common/store";
  import { Toaster } from "svelte-sonner";
</script>

<body>
  <div class="flex items-center">
    <!-- <Navbar /> -->
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
</body>
