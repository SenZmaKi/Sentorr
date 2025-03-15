<script lang="ts">
  import Seekbar from "./Seekbar.svelte";
  import PlayPause from "./PlayPause.svelte";
  import { fade } from "svelte/transition";
  import { isHovering } from "./common/store";
  import {
    video,
    duration,
    paused,
    currentTime,
    buffered,
    playerTorrentStream,
    videoHeight,
    videoWidth,
  } from "../common/store";
  import { createThumbnailGenerator } from "./common/thumbnail";
  import Next from "./Next.svelte";
  import Volume from "./volume/Volume.svelte";
  import Time from "./Time.svelte";
  import SettingIcon from "./settings/Icon.svelte";
  import SettingModal from "./settings/modal/Modal.svelte";

  let progress = 0;
  $: buffer =
    $buffered && $buffered.length > 0
      ? ($buffered[$buffered.length - 1].end / $duration) * 100
      : 0;
  let show = false;
  let hidetimer: Timer | undefined = undefined;
  $: thumbnailGenerator =
    $playerTorrentStream &&
    createThumbnailGenerator(
      $playerTorrentStream.url,
      $videoHeight,
      $videoWidth,
    );

  $: if ($video) {
    $video.addEventListener("timeupdate", () => {
      progress = computeProgress($currentTime);
    });
  }

  function computeProgress(time: number) {
    return time && $duration ? (time / $duration) * 100 : 0;
  }

  function showWithTimeout() {
    if ($paused || $isHovering) return;
    if (hidetimer) clearTimeout(hidetimer);
    show = true;
    hidetimer = setTimeout(() => {
      show = false;
    }, 3_000);
  }

  function onSeeking(percent: number) {
    $currentTime = (percent / 100) * $duration;
  }
  if ($paused) {
    clearTimeout(hidetimer);
    show = false;
  }
  $: if ($video) {
    $video.addEventListener("mousemove", showWithTimeout);
  }
</script>

{#if isHovering || $paused || $isHovering}
  <div
    transition:fade
    style="background: radial-gradient(oval, rgba(0,0,0,0.8) 0%, transparent 70%);"
    class="flex flex-col items-center justify-center w-full"
  >
    <div class="w-[98%]">
      <div class="flex justify-end">
        <SettingModal />
      </div>
      <Seekbar
        bind:progress
        {buffer}
        length={$duration}
        {onSeeking}
        {thumbnailGenerator}
      />
      <div class="flex justify-between p-5 pb-0">
        <div class="flex items-center gap-x-6">
          <PlayPause />
          <Next />
          <Volume />
          <Time />
        </div>
        <div class="flex">
          <SettingIcon />
        </div>
      </div>
    </div>
  </div>
{/if}
