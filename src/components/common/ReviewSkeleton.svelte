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
      class="rounded bg-gray-700 mb-4"
      style="width: {placeHoldersWidth}px; height: {height * 0.15}px;"
    ></div>
    <div class="mb-3">
      {#each Array.from({ length: 8 }) as _}
        <div
          class="rounded bg-gray-700 mb-[2px]"
          style="width: {placeHoldersWidth}; height: {height * 0.04}px"
        ></div>
      {/each}
    </div>
    <div
      class="rounded bg-gray-700 mb-2"
      style="-width: {placeHoldersWidth}; height: {height * 0.05}px"
    ></div>
    <div
      class="rounded bg-gray-700"
      style="width: {placeHoldersWidth}; height: {height * 0.1}px"
    ></div>
  </div>
</div>
