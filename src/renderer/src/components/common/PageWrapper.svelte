<script lang="ts">
  import { useMiniplayer } from "../player/common/store";
  import Player from "../player/Player.svelte";

  export let hidden: boolean;
</script>

<div class=" {hidden ? 'hidden' : ''}">
  <div class="relative">
    <slot />
    {#if $useMiniplayer}
      <div class="absolute bottom-2 right-4">
        <Player />
      </div>
    {/if}
  </div>
</div>
