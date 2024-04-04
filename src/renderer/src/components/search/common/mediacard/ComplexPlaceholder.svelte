<script lang="ts">
  import ImagePlaceholder from "./ImagePlaceholder.svelte";
  import { randomNumber } from "@/utils/functions";

</script>

<div class="xxs-dark flex w-[550px] h-[280px]">
  <ImagePlaceholder animate={true} width="200px" />

  <div class="animate-pulse p-3">
    {#each Array.from({ length: 12 }, (_) => undefined) as _}
      <div
        class=" bg-gray-200 rounded-full dark:bg-gray-700"
        style=" width: {randomNumber({
          min: 500 * 0.2 ,
          max: (500 - 200) - 15,
        })}px;
          height: {randomNumber({ min: 6, max: 10 })}px;
        margin-bottom: {randomNumber({ min: 1, max: 13 })}px"
      ></div>
    {/each}
    <div
      class="h-2 bg-gray-200 rounded-full dark:bg-gray-700 max-w-[360px] mb-2.5"
    ></div>
  </div>
</div>
