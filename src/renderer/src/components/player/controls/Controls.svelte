<script lang="ts">
  import Seekbar from "./Seekbar.svelte";
  import PlayPause from "./PlayPause.svelte";
  import { fade } from "svelte/transition";
  import { isHovering } from "./common/store";
  import { createThumbnailGenerator } from "./common/thumbnail";
  import Next from "./Next.svelte";

  export let video: HTMLVideoElement;
  let progress = 0;
  let buffer = 0;
  let show = false;
  let length = video.duration;
  let hidetimer: Timer | undefined = undefined;
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
    progress = (video.currentTime / video.duration) * 100;
  };
  video.onmousemove = () => {
    showWithTimeout();
  };
</script>

{#if true || video.paused || $isHovering}
  <div
    transition:fade
    style="background: radial-gradient(oval, rgba(0,0,0,0.8) 0%, transparent 70%);"
    class="flex flex-col items-center justify-center w-full"
  >
    <div class="w-[98%]">
      <Seekbar
        bind:progress
        {buffer}
        {length}
        {onSeeking}
        {thumbnailGenerator}
      />
      <div class="pt-5 pl-3 flex">
        <PlayPause {video} />
        <div class="pr-6"></div>
        <Next />
      </div>
    </div>
  </div>
{/if}
