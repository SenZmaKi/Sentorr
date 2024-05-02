<script lang="ts">
  import ImageSkeleton from "../ImageSkeleton.svelte";
</script>

<div class="xxs-dark flex w-[550px] h-[280px]">
  <ImageSkeleton animate={true} width={200} height={280} />

  <div class="animate-pulse p-3">
    <div class="min-h-[35px] w-[325px] rounded bg-gray-700 mb-2"></div>
    <div class="min-h-[15px] w-[200px] rounded bg-gray-700 mb-3"></div>
    <div class="mb-5">
      {#each Array.from({ length: 15 }) as _}
        <div class="min-h-[5px] w-[326px] rounded bg-gray-700 mb-[2px]"></div>
      {/each}
    </div>
    <div class="min-h-[15px] w-[200px] rounded bg-gray-700 mb-3"></div>
  </div>
</div>
