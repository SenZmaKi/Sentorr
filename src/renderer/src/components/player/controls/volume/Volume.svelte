<script lang="ts">
  import { slide } from "svelte/transition";
  import Seekbar from "../Seekbar.svelte";
  import Icon from "./Icon.svelte";
  import { hoverManager } from "../common/functions";

  export let video: HTMLVideoElement;
  let isHovering = false;
  let progress = video.volume;
  $: volume = progress / 100;
  $: video.volume = volume;
  const { onPointerEnter, onPointerLeave } = hoverManager();
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
  <Icon {video} {volume} />
  {#if isHovering}
    <div transition:slide={{ axis: "x" }} class="w-[100px]">
      <div>
        <Seekbar bind:progress />
      </div>
    </div>
  {/if}
</div>
