<script lang="ts">
  import { slide } from "svelte/transition";
  import Seekbar from "../Seekbar.svelte";
  import Icon from "./Icon.svelte";
  import { volume } from "../../common//store";
  import HoverWrapper from "../common/HoverWrapper.svelte";
  import TooltipWrapper from "../common/TooltipWrapper.svelte";

  let progress = $volume * 100;
  $: $volume = progress / 100;
  let isHovering = false;
</script>

<HoverWrapper bind:isHovering>
  <div class="flex items-center justify-center cursor-pointer gap-x-4">
    <Icon />
    {#if isHovering}
      <TooltipWrapper tooltip={`${progress.toFixed(0)}%`}>
        <div transition:slide={{ axis: "x" }} class="w-[100px]">
          <Seekbar bind:progress />
        </div>
      </TooltipWrapper>
    {/if}
  </div>
</HoverWrapper>
