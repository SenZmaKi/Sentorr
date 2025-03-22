<script lang="ts">
  import { slide } from "svelte/transition";
  import { showSettingsModal, icon } from "./../store";
  import ResolutionField from "./resolution/Field.svelte";
  import SleepTimerField from "./sleeptimer/Field.svelte";
  import PlaybackRateField from "./playbackRate/Field.svelte";
  import ResolutionModal from "./resolution/Modal.svelte";
  import PlaybackRateModal from "./playbackRate/Modal.svelte";
  import SleepTimerModal from "./sleeptimer/Modal.svelte";
  import { currentFieldModal } from "./common/store";
  import { Field } from "./common/types";
  import { onMount, onDestroy } from "svelte";
    import { showControlsWithTimeout } from "../../common/store";

  let modal: HTMLDivElement | undefined = undefined;

  function onDocClick(event: MouseEvent) {
    console.log("document clicked");
    console.log("modal is:", modal);
    const wasClicked = (element: HTMLElement | undefined) =>
      element && event.composedPath().includes(element);
    if (wasClicked(modal) || wasClicked($icon)) return;
    console.log("click was outside modal");
    $showSettingsModal = false;
    $currentFieldModal = undefined;
    showControlsWithTimeout();
  }

  onMount(() => {
    document.addEventListener("click", onDocClick);
  });
  onDestroy(() => {
    document.removeEventListener("click", onDocClick);
  });
</script>

{#if $showSettingsModal}
  <div bind:this={modal} transition:slide>
    <button>
      <div class="bg-black rounded-xl bg-opacity-70 w-[325px]">
        {#if !$currentFieldModal}
          <div class="rounded-xl flex-col flex">
            <div class="flex flex-col gap-4 pt-2 pb-2">
              <ResolutionField />
              <PlaybackRateField />
              <SleepTimerField />
            </div>
          </div>
        {:else if $currentFieldModal === Field.Resolution}
          <ResolutionModal />
        {:else if $currentFieldModal === Field.PlaybackRate}
          <PlaybackRateModal />
        {:else if $currentFieldModal === Field.SleepTimer}
          <SleepTimerModal />
        {/if}
      </div>
    </button>
  </div>
{/if}
