<script lang="ts">
  import Search from "./components/search/Search.svelte";
  import Preview from "./components/preview/Preview.svelte";
  import Player from "./components/player/Player.svelte";
  import Navbar from "./components/navbar/Navbar.svelte";
  import { Toaster } from "svelte-sonner";
</script>

<div class="flex w-screen">
  <Navbar />
  <div class="w-[95vw] relative h-screen">
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
    <!-- Must be the last component cause of miniplayer -->
    <Player />
  </div>
</div>
