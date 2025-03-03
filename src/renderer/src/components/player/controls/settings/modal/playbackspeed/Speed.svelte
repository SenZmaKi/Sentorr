<script lang="ts">
    import {  computeProgress } from "./common/functions";

  export let speed: number;
  export let progress: number;
</script>

<button
  on:click={() => {
    progress = computeProgress(speed);
  }}
  class="rounded-xl w-full p-2 hover:bg-gray-700 hover:bg-opacity-80"
>
  {speed == 1 ? "Normal" : speed}
</button>
