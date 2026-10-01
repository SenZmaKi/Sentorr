<script lang="ts">
  export let width: number;
  export let height: number;
  let placeHoldersWidth = width * 0.9;
</script>

<div
  class="xxs-dark flex m-4 rounded"
  style="min-width: {width}px; height: {height}px;"
>
  <div class="animate-pulse p-3">
    <div
      class="rounded bg-gray-700 mb-6"
      style="width: {placeHoldersWidth}px; height: 10px;"
    ></div>
    <div class="mb-4">
      <div class="rounded bg-gray-700 mb-1 w-[220px] h-[5px]"></div>
      <div class="rounded bg-gray-700 mb-1 w-[210px] h-[5px]"></div>
      <div class="rounded bg-gray-700 mb-1 w-[190px] h-[5px]"></div>
      <div class="rounded bg-gray-700 mb-1 w-[180px] h-[5px]"></div>
      <div class="rounded bg-gray-700 mb-1 w-[190px] h-[5px]"></div>
      <div class="rounded bg-gray-700 mb-1 w-[210px] h-[5px]"></div>
      <div class="rounded bg-gray-700 mb-1 w-[220px] h-[5px]"></div>
    </div>
    <div class="rounded bg-gray-700 mb-2 w-[100px] h-[10px]"></div>
    <div class="rounded bg-gray-700 mb-2 w-[200px] h-[10px]"></div>
  </div>
</div>
