<script lang="ts">
  import ImageSkeleton from "../ImageSkeleton.svelte";
</script>

<div class="xxs-dark flex w-[480px] h-[240px]">
  <div class="w-[480px]">
    <ImageSkeleton animate={true} width={160} height={240} />
  </div>

  <div class="animate-pulse p-3">
    <div class="min-h-[35px] w-[300px] rounded bg-gray-700 mb-2"></div>
    <div class="min-h-[15px] w-[200px] rounded bg-gray-700 mb-3"></div>
    <div class="mb-5">
      {#each Array.from({ length: 15 }) as _}
        <div class="min-h-[5px] w-[300px] rounded bg-gray-700 mb-[2px]"></div>
      {/each}
    </div>
    <div class="min-h-[15px] w-[200px] rounded bg-gray-700 mb-3"></div>
  </div>
</div>
