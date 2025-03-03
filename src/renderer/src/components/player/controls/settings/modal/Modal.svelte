<script lang="ts">
  import { slide } from "svelte/transition";
  import { isHoveringWithTimer, updateIsHoveringWithTimer } from "./../store";
  import Button from "../../Button.svelte";
  import Resolution from "./resolution/Field.svelte";
  import ResolutionModal from "./resolution/Modal.svelte";
  import PlaybackSpeed from "./playbackspeed/Field.svelte";
  import PlaybackSpeedModal from "./playbackspeed/Modal.svelte";
  import { currentFieldModal } from "./common/store";
  import { Field } from "./common/types";

  export let video: HTMLVideoElement;
  let isHovering = false;
  $: updateIsHoveringWithTimer(isHovering);
  $: if (!$isHoveringWithTimer) {
    $currentFieldModal = undefined;
  }
</script>

{#if isHovering || $isHoveringWithTimer}
  <div transition:slide>
    <Button bind:isHovering setHoverScale={false} setSize={false}>
      <div class="bg-black rounded-xl bg-opacity-70 w-[300px]">
        {#if !$currentFieldModal}
          <div class="rounded-xl flex-col flex">
            <div class="flex flex-col gap-4 pt-2 pb-2">
              <Resolution />
              <PlaybackSpeed />
            </div>
          </div>
        {:else if $currentFieldModal === Field.Resolution}
          <ResolutionModal />
        {:else if $currentFieldModal === Field.PlaybackSpeed}
          <PlaybackSpeedModal {video} />
        {/if}
      </div>
    </Button>
  </div>
{/if}
