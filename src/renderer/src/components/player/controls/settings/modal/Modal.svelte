<script lang="ts">
  import { slide } from "svelte/transition";
  import { isHoveringWithTimer, updateIsHoveringWithTimer } from "./../store";
  import Button from "../../Button.svelte";
  import ResolutionField from "./resolution/Field.svelte";
  import SleepTimerField from "./sleeptimer/Field.svelte";
  import PlaybackSpeedField from "./playbackspeed/Field.svelte";
  import ResolutionModal from "./resolution/Modal.svelte";
  import PlaybackSpeedModal from "./playbackspeed/Modal.svelte";
  import SleepTimerModal from "./sleeptimer/Modal.svelte";
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
      <div class="bg-black rounded-xl bg-opacity-70 w-[325px]">
        {#if !$currentFieldModal}
          <div class="rounded-xl flex-col flex">
            <div class="flex flex-col gap-4 pt-2 pb-2">
              <ResolutionField />
              <PlaybackSpeedField />
              <SleepTimerField />
            </div>
          </div>
        {:else if $currentFieldModal === Field.Resolution}
          <ResolutionModal />
        {:else if $currentFieldModal === Field.PlaybackSpeed}
          <PlaybackSpeedModal {video} />
        {:else if $currentFieldModal === Field.SleepTimer}
          <SleepTimerModal  />
        {/if}
      </div>
    </Button>
  </div>
{/if}
