<script lang="ts">
  import Search from "./components/search/Search.svelte";
  import Preview from "./components/preview/Preview.svelte";
  import Player from "./components/player/Player.svelte";
  import Navbar from "./components/navbar/Navbar.svelte";
  import { Toaster } from "svelte-sonner";
  import { useMiniplayer } from "./components/player/common/store";
</script>

<body>
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

      <Search />
      <Preview />
      {#if !$useMiniplayer}
        <Player />
      {/if}
    </div>
  </div>
</body>
