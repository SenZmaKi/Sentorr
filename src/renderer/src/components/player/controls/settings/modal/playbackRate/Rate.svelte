<script lang="ts">
    import {  computeProgress } from "./common/functions";

  export let rate: number;
  export let progress: number;
</script>

<button
  on:click={() => {
    progress = computeProgress(rate);
  }}
  class="rounded-xl w-full p-2 hover:bg-gray-700 hover:bg-opacity-80"
>
  {rate == 1 ? "Normal" : rate}
</button>
