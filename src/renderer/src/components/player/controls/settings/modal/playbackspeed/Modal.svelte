<script lang="ts">
  import Seekbar from "../../../Seekbar.svelte";
  import FieldModal from "../common/FieldModal.svelte";
  import { Field } from "../common/types";
  import { computePlaybackSpeed, computeProgress } from "./common/functions";
  import Icon from "./Icon.svelte";
  import { playbackSpeed } from "@/renderer/src/components/player/store";
  import Radio from "../common/Radio.svelte";

  export let video: HTMLVideoElement;

  let progress = computeProgress($playbackSpeed);

  $: {
    $playbackSpeed = computePlaybackSpeed(progress);
    video.playbackRate = $playbackSpeed;
  }
</script>

<FieldModal field={Field.PlaybackSpeed}>
  <Icon slot="icon" />
  <div
    class="flex flex-col items-center justify-center gap-y-4 w-full"
    slot="contents"
  >
    <div class="flex flex-col gap-2 items-center justify-center w-full">
      <div>{$playbackSpeed}x</div>
      <Seekbar bind:progress alwaysShowThumb={true} />
    </div>
    <Radio
      variants={[0.25, 0.5, 0.75, 1, 1.25, 1.75, 2.05]}
      currentVariant={$playbackSpeed}
      onVariantChange={(variant) => {
        progress = computeProgress(variant);
      }}
      variantToString={(variant) => (variant === 1 ? "Normal" : `${variant}`)}
    />
  </div>
</FieldModal>
