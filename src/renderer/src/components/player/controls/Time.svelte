<script lang="ts">
  import { scale } from "svelte/transition";
  import Button from "./Button.svelte";
  import { timeStamp } from "./common/functions";
  import { currentTime, duration } from "../common/store";

  export let useElapsedTime = false;
  let currentTimeWidth: number;
  let currentTimeHeight: number;
  function onClick() {
    useElapsedTime = !useElapsedTime;
  }
</script>

<Button style="" setHoverScale={false} setSize={false} {onClick}>
  <div class="relative">
    <div class="flex items-center font-bold gap-x-2">
      <div
        class="relative"
        style="width: {currentTimeWidth}px; height: {currentTimeHeight}px;"
      >
        {#key useElapsedTime}
          <!-- CSS man...-->
          <div
            bind:clientWidth={currentTimeWidth}
            bind:clientHeight={currentTimeHeight}
            class="absolute left-0"
            transition:scale
          >
            {useElapsedTime
              ? `-${timeStamp($duration - $currentTime)}`
              : timeStamp($currentTime)}
          </div>
        {/key}
      </div>
      <div>/</div>
      <div>{timeStamp($duration)}</div>
    </div>
  </div>
</Button>
