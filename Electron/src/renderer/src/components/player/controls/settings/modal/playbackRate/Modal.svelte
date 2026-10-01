<script lang="ts">
  import Seekbar from "../../../Seekbar.svelte";
  import FieldModal from "../common/FieldModal.svelte";
  import { Field } from "../common/types";
  import { computePlaybackRate, computeProgress } from "./common/functions";
  import Icon from "./Icon.svelte";
  import { playbackRate } from "../../../.../../../common/store";
  import Radio from "../common/Radio.svelte";

  let progress = computeProgress($playbackRate);

  $: {
    $playbackRate = computePlaybackRate(progress);
  }
</script>

<FieldModal field={Field.PlaybackRate}>
  <Icon slot="icon" />
  <div
    class="flex flex-col items-center justify-center gap-y-4 w-full"
    slot="contents"
  >
    <div class="flex flex-col gap-2 items-center justify-center w-full">
      <div>{$playbackRate}x</div>
      <Seekbar bind:progress alwaysShowThumb={true} />
    </div>
    <Radio
      variants={[0.25, 0.5, 0.75, 1, 1.25, 1.75, 2.05]}
      currentVariant={$playbackRate}
      onVariantChange={(variant) => {
        progress = computeProgress(variant);
      }}
      variantToString={(variant) => (variant === 1 ? "Normal" : `${variant}`)}
    />
  </div>
</FieldModal>
