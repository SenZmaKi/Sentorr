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
    progress,
    showControls,
    playerMedia,
    playerEpisode,
  } from "../common/store";
  import { showSettingsModal } from "./settings/store";
  import {
    showControlsWithTimeout,
    showControlsTimedOut,
  } from "./common/store";
  import { createThumbnailGenerator } from "./common/thumbnail";
  import Next from "./Next.svelte";
  import Volume from "./volume/Volume.svelte";
  import Time from "./Time.svelte";
  import SettingsIcon from "./settings/Icon.svelte";
  import SettingsModal from "./settings/modal/Modal.svelte";
  import Fullscreen from "./Fullscreen.svelte";
  import Pip from "./Pip.svelte";
  import { onDestroy } from "svelte";
  import { config } from "../../common/store";

  function computeProgress(time: number) {
    return time && $duration ? (time / $duration) * 100 : 0;
  }

  function onSeeking(percent: number) {
    if ($video) $video.currentTime = (percent / 100) * $duration;
  }

  function updateProgress() {
    if (!$video) return;
    $currentTime = $video.currentTime;
    $progress = computeProgress($currentTime);

    if (!$playerMedia || !$currentTime || !$duration) return;
    const { allMediaProgress } = $config;
    allMediaProgress.current = $playerMedia.id;
    const episode = $playerEpisode && {
      id: $playerEpisode.id,
      title: $playerEpisode.title,
      seasonEpisode: $playerEpisode.seasonEpisode,
      currentTime: $currentTime,
      duration: $duration,
    };
    allMediaProgress.mediaProgress[allMediaProgress.current] = {
      id: $playerMedia.id,
      title: $playerMedia.title,
      watchTime: {
        currentTime: $currentTime,
        duration: $duration,
      },
      episode,
    };
    $config = { ...$config, allMediaProgress: allMediaProgress };
  }

  function addVideoListeners(video: HTMLVideoElement) {
    video.addEventListener("mousemove", showControlsWithTimeout);
    video.addEventListener("timeupdate", updateProgress);
  }

  onDestroy(() => {
    if (!$video) return;
    $video.removeEventListener("mousemove", showControlsWithTimeout);
    $video.removeEventListener("timeupdate", updateProgress);
  });

  $: buffer =
    $buffered && $buffered.length
      ? ($buffered[$buffered.length - 1].end / $duration) * 100
      : 0;
  $: thumbnailGenerator =
    $playerTorrentStream &&
    createThumbnailGenerator(
      $playerTorrentStream.url,
      $videoHeight,
      $videoWidth,
    );
  $: $video && addVideoListeners($video);
  // Don't hide controls immediately after user stops hovering, it looks janky
  $: if (!$isHovering) showControlsWithTimeout();
  $: $showControls =
    !$showControlsTimedOut || $paused || $isHovering || $showSettingsModal;
  $: if (!$showControls) {
  }
</script>

<div
  class="flex flex-col items-center justify-center w-full"
  class:hidden={!$showControls}
  transition:fade
>
  <div class="w-full">
    <div class="flex justify-end">
      <SettingsModal />
    </div>
    <div
      class="w-full flex flex-col items-center bg-gradient-to-t from-black/80 to-transparent pb-7 pt-3"
    >
      <div class="w-[98%]">
        <Seekbar
          bind:progress={$progress}
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
          <div class="flex items-center gap-x-6">
            <SettingsIcon />
            <Fullscreen />
            <Pip />
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
