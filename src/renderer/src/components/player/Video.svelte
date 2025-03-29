<script lang="ts">
  import {
    muted,
    volume,
    ended,
    playbackRate,
    video,
    buffered,
    paused,
    duration,
    videoHeight,
    videoWidth,
    src,
  } from "./common/store";

  export let onError: (error: MediaError) => void;
  export let onLoadedMetadata: () => void;

  $: console.log("video src;", $src);
</script>

<!-- svelte-ignore a11y-media-has-caption -->
<video
  crossorigin="anonymous"
  src={$src}
  bind:muted={$muted}
  bind:volume={$volume}
  bind:playbackRate={$playbackRate}
  bind:ended={$ended}
  bind:buffered={$buffered}
  bind:paused={$paused}
  bind:duration={$duration}
  bind:videoWidth={$videoWidth}
  bind:videoHeight={$videoHeight}
  bind:this={$video}
  on:error={() => {
    if (!$video) return;
    const error = $video.error;
    if (!error) return;
    onError(error);
  }}
  on:loadedmetadata={onLoadedMetadata}
>
</video>
