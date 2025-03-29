<script lang="ts">
  import { scale } from "svelte/transition";
  import TooltipWrapper from "././common/TooltipWrapper.svelte";

  import { timeStamp } from "../../common/functions";
  import { currentTime, duration } from "../common/store";
  import HoverWrapper from "./common/HoverWrapper.svelte";

  export let showElapsedTime = true;
  let currentTimeWidth: number;
  let currentTimeHeight: number;
  function onClick() {
    showElapsedTime = !showElapsedTime;
  }
</script>

<button on:click={onClick}>
  <HoverWrapper>
    <TooltipWrapper
      tooltip={showElapsedTime ? "Show remaining time" : "Show elapsed time"}
    >
      <div class="relative">
        <div class="flex items-center font-bold gap-x-2">
          <div
            class="relative"
            style="width: {currentTimeWidth}px; height: {currentTimeHeight}px;"
          >
            {#key showElapsedTime}
              <!-- TODO: Find a better way to do this-->
              <div
                bind:clientWidth={currentTimeWidth}
                bind:clientHeight={currentTimeHeight}
                class="absolute left-0"
                transition:scale
              >
                {showElapsedTime
                  ? timeStamp($currentTime)
                  : `-${timeStamp($duration - $currentTime)}`}
              </div>
            {/key}
          </div>
          <div>/</div>
          <div>{timeStamp($duration)}</div>
        </div>
      </div>
    </TooltipWrapper>
  </HoverWrapper>
</button>
