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
  import { showModal } from "./settings/store";
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

  function showWithTimeout() {
    if ($paused || $isHovering) return;
    if (hideTimer) {
      clearTimeout(hideTimer);
      hideTimer = undefined;
    }
    show = true;
    hideTimer = setTimeout(() => {
      show = false;
    }, 3_000);
  }

  function onSeeking(percent: number) {
    if ($video) $video.currentTime = (percent / 100) * $duration;
  }

  function showWithPaused(paused: boolean) {
    if (paused) {
      if (hideTimer) {
        clearTimeout(hideTimer);
        hideTimer = undefined;
      }
      show = false;
    } else {
      showWithTimeout();
    }
  }
  function updateProgress() {
    if (!$video) return;
    $currentTime = $video.currentTime;
    $progress = computeProgress($currentTime);

    if (!$playerMedia) return;
    const { allMediaProgress } = $config;
    allMediaProgress.current = $playerMedia.id;
    const episode = $playerEpisode && {
      id: $playerEpisode.id,
      title: $playerEpisode.title,
      seasonEpisode: $playerEpisode.seasonEpisode,
    };
    allMediaProgress.mediaProgress[allMediaProgress.current] = {
      id: $playerMedia.id,
      title: $playerMedia.title,
      time: $currentTime,
      episode,
    };
    $config = { ...$config, allMediaProgress: allMediaProgress };
  }
  function addVideoListeners(video: HTMLVideoElement) {
    video.addEventListener("mousemove", showWithTimeout);
    video.addEventListener("timeupdate", updateProgress);
  }

  onDestroy(() => {
    if (!$video) return;
    $video.removeEventListener("mousemove", showWithTimeout);
    $video.removeEventListener("timeupdate", updateProgress);
  });

  let show = false;
  let hideTimer: Timer | undefined = undefined;

  $: buffer =
    $buffered && $buffered.length > 0
      ? ($buffered[$buffered.length - 1].end / $duration) * 100
      : 0;
  $: thumbnailGenerator =
    $playerTorrentStream &&
    createThumbnailGenerator(
      $playerTorrentStream.url,
      $videoHeight,
      $videoWidth,
    );
  $: showWithPaused($paused);
  $: $video && addVideoListeners($video);
  $: $showControls = show || $paused || $isHovering || $showModal;
</script>

<div
  class:hidden={!$showControls}
  transition:fade
  style="background: radial-gradient(oval, rgba(0,0,0,0.8) 0%, transparent 70%);"
  class="flex flex-col items-center justify-center w-full"
>
  <div class="w-[98%]">
    <div class="flex justify-end">
      <SettingsModal />
    </div>
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
