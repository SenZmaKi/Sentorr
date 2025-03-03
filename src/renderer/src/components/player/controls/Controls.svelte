<script lang="ts">
  import Seekbar from "./Seekbar.svelte";
  import PlayPause from "./PlayPause.svelte";
  import { fade } from "svelte/transition";
  import { isHovering } from "./common/store";
  import { createThumbnailGenerator } from "./common/thumbnail";
  import Next from "./Next.svelte";
  import Volume from "./volume/Volume.svelte";
  import Time from "./Time.svelte";
  import SettingIcon from "./settings/Icon.svelte";
  import SettingModal from "./settings/modal/Modal.svelte";

  export let video: HTMLVideoElement;
  let progress = 0;
  let buffer = 0;
  let show = false;
  let duration = video.duration;
  let hidetimer: Timer | undefined = undefined;
  let currentTime = video.currentTime;
  const thumbnailGenerator = createThumbnailGenerator(video);

  function showWithTimeout() {
    if (video.paused || $isHovering) return;
    if (hidetimer) clearTimeout(hidetimer);
    show = true;
    hidetimer = setTimeout(() => {
      show = false;
    }, 3_000);
  }
  function onSeeking(progress: number) {
    video.currentTime = (progress / 100) * video.duration;
  }
  video.onpause = () => {
    clearTimeout(hidetimer);
    show = false;
  };
  video.onprogress = () => {
    if (video && video.buffered.length > 0) {
      buffer =
        (video.buffered.end(video.buffered.length - 1) / video.duration) * 100;
    }
  };
  video.ontimeupdate = () => {
    currentTime = video.currentTime;
    progress = (currentTime / video.duration) * 100;
  };
  video.onmousemove = () => {
    showWithTimeout();
  };
</script>

{#if isHovering || video.paused || $isHovering}
  <div
    transition:fade
    style="background: radial-gradient(oval, rgba(0,0,0,0.8) 0%, transparent 70%);"
    class="flex flex-col items-center justify-center w-full"
  >
    <div class="w-[98%]">
      <div class="flex justify-end">
        <SettingModal {video}/>
      </div>
      <Seekbar
        bind:progress
        {buffer}
        length={duration}
        {onSeeking}
        {thumbnailGenerator}
      />
      <div class="flex justify-between p-5 pb-0">
        <div class="flex items-center gap-x-6">
          <PlayPause {video} />
          <Next />
          <Volume {video} />
          <Time {currentTime} {duration} />
        </div>
        <div class="flex">
          <SettingIcon />
        </div>
      </div>
    </div>
  </div>
{/if}
