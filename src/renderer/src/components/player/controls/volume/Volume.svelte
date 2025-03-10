<script lang="ts">
  import { slide } from "svelte/transition";
  import Seekbar from "../Seekbar.svelte";
  import Icon from "./Icon.svelte";
  import { hoverManager } from "../common/functions";
  import { volume } from "../../common//store";

  let isHovering = false;
  const { onPointerEnter, onPointerLeave } = hoverManager();
  let progress = $volume * 100;
  $: $volume = progress / 100;
</script>

<div
  on:pointerenter={() => {
    isHovering = true;
    onPointerEnter();
  }}
  on:pointerleave={() => {
    isHovering = false;
    onPointerLeave();
  }}
  class="flex items-center justify-center cursor-pointer gap-x-4"
>
  <Icon />
  {#if isHovering}
    <div transition:slide={{ axis: "x" }} class="w-[100px]">
      <div>
        <Seekbar bind:progress />
      </div>
    </div>
  {/if}
</div>
