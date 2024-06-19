<script lang="ts">
  import ImageSkeleton from "../ImageSkeleton.svelte";
</script>

<div class="xxs-dark flex w-[480px] h-[240px]">
  <div class="w-[480px]">
    <ImageSkeleton animate={true} width={160} height={240} />
  </div>

  <div class="animate-pulse p-3">
    <div class="mb-5">
      <div class="min-h-[10px] w-[300px] rounded bg-gray-700 mb-2"></div>
      <div class="min-h-[10px] w-[200px] rounded bg-gray-700 "></div>
    </div>
    <div class="mb-5">
      <div class="min-h-[8px] w-[300px] rounded bg-gray-700 mb-2"></div>
      <div class="min-h-[8px] w-[280px] rounded bg-gray-700 mb-2"></div>
      <div class="min-h-[8px] w-[260px] rounded bg-gray-700 mb-2"></div>
      <div class="min-h-[8px] w-[230px] rounded bg-gray-700 mb-2"></div>
      <div class="min-h-[8px] w-[260px] rounded bg-gray-700 mb-2"></div>
      <div class="min-h-[8px] w-[300px] rounded bg-gray-700 mb-2"></div>
    </div>
    <div class="min-h-[10px] w-[200px] rounded bg-gray-700 mb-3"></div>
  </div>
</div>
